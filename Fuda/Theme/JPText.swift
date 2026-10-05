import SwiftUI

// MARK: - Furigana alignment
// Lines up a sentence with its full kana reading so each kanji run gets its
// own reading: 毎朝パンを食べます + まいあさぱんをたべます →
// [毎朝|まいあさ][パ][ン][を][食|た][べ][ま][す]. Kana runs must match the reading
// (katakana compared as hiragana); kanji runs take whatever lies between.

enum Furigana {
    struct Seg: Hashable {
        let base: String
        let ruby: String?          // nil for kana / punctuation
    }

    nonisolated(unsafe) private static var cache: [String: [Seg]] = [:]

    static func isKanji(_ c: Character) -> Bool {
        c == "々" || c == "ヶ" || c == "〆" || c.unicodeScalars.contains { $0.properties.isIdeographic }
    }

    static func segments(_ ja: String, _ kana: String) -> [Seg] {
        let key = ja + "\u{1}" + kana
        if let hit = cache[key] { return hit }
        let out = align(ja, kana)
        cache[key] = out
        return out
    }

    private static func align(_ ja: String, _ kanaIn: String) -> [Seg] {
        let kana = KanaData.toHiragana(kanaIn.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: ""))
        // Runs of kanji vs everything else.
        var runs: [(String, Bool)] = []
        for ch in ja {
            let k = isKanji(ch)
            if let last = runs.last, last.1 == k { runs[runs.count - 1].0.append(ch) } else { runs.append((String(ch), k)) }
        }
        guard runs.contains(where: { $0.1 }) else { return ja.map { Seg(base: String($0), ruby: nil) } }
        var pattern = "^"
        for (text, kanji) in runs {
            pattern += kanji ? "(.+?)" : NSRegularExpression.escapedPattern(for: KanaData.toHiragana(text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")))
        }
        pattern += "$"
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: kana, range: NSRange(kana.startIndex..., in: kana)) else {
            return [Seg(base: ja, ruby: kanaIn == ja ? nil : kanaIn)]           // couldn't align: reading over the whole thing
        }
        var segs: [Seg] = []
        var group = 1
        for (text, kanji) in runs {
            if kanji {
                let r = Range(m.range(at: group), in: kana).map { String(kana[$0]) }
                segs.append(Seg(base: text, ruby: r))
                group += 1
            } else {
                segs += text.map { Seg(base: String($0), ruby: nil) }   // one per char so lines can wrap anywhere
            }
        }
        return segs
    }

    /// Romaji with particles split out: 朝ご飯を食べます → "asagohan o tabemasu",
    /// 私は → "watashi wa". A particle is one of を は が に で と へ も の sitting
    /// between a kanji/katakana word and the next word.
    nonisolated(unsafe) private static var romajiCache: [String: String] = [:]

    static func romaji(_ ja: String, _ kana: String) -> String {
        let key = ja + "\u{1}" + kana
        if let hit = romajiCache[key] { return hit }
        let out = wordRomaji(ja, kana) ?? simpleRomaji(ja, kana)
        romajiCache[key] = out
        return out
    }

    /// Word-spaced romaji: the system tokenizer finds the word boundaries, our
    /// own kana gives the readings. "タムさんはタイ人です" → "tamu san wa taijin desu".
    private static func wordRomaji(_ ja: String, _ kana: String) -> String? {
        let segs = segments(ja, kana)
        guard segs.count > 1 || segs.first?.ruby == nil else { return nil }   // alignment failed
        // Character offset → reading of that character's segment (kanji runs read once, at their start).
        var readingAt: [Int: String] = [:]
        var pos = 0
        for sg in segs {
            readingAt[pos] = sg.ruby ?? KanaData.toHiragana(sg.base)
            for k in 1..<max(1, sg.base.count) { readingAt[pos + k] = "" }
            pos += sg.base.count
        }
        // Auxiliaries the tokenizer splits off (食べ|まし|た, あり|ませ|ん) join the word before.
        let glue: Set<String> = ["ます", "まし", "ませ", "ましょ", "ましょう", "ん", "た", "て", "たい", "たく", "たかっ", "ない", "なく", "なかっ",
                                 "られ", "られる", "れ", "れる", "せ", "せる", "させ", "させる", "ず", "ば", "ちゃ", "ちゃう", "じゃう", "う", "よう"]
        // Each word keeps its kana until the end, so っ across a token boundary (行っ|た) romanises right.
        struct Word { var kana = ""; var fixed: String?; var punct = "" }
        var words: [Word] = []
        var cursor = 0
        var prevSurface = ""
        for t in AutoReading.tokens(ja) {
            let n = t.surface.count
            var r = ""
            for k in cursor..<(cursor + n) { r += readingAt[k] ?? "" }
            cursor += n
            let trimmed = t.surface.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            // The rest of a kanji run whose reading already went to the previous token (中国|人 in 中国人).
            if r.isEmpty, trimmed.allSatisfy(Furigana.isKanji) { prevSurface = trimmed; continue }
            if trimmed.allSatisfy({ "、。，．！？!?「」『』（）()…・〜ー　".contains($0) }) {
                let p = trimmed.map { c -> String in ["、": ",", "。": ".", "？": "?", "！": "!", "?": "?", "!": "!"][c] ?? "" }.joined()
                if !words.isEmpty { words[words.count - 1].punct += p }
                prevSurface = trimmed
                continue
            }
            var fixed: String?
            switch trimmed {
            case "は" where !words.isEmpty: fixed = "wa"
            case "へ" where !words.isEmpty: fixed = "e"
            case "を": fixed = "o"
            case "こんにちは": fixed = "konnichiwa"
            case "こんばんは": fixed = "konbanwa"
            default: break
            }
            let kana = r.isEmpty ? KanaData.toHiragana(trimmed) : r
            // 飲ん|で, 泳い|だ: で/だ after a verb stem (kanji + ん/い) is the て-form, not the particle (かばん|で).
            let stem = Array(prevSurface)
            let teDe = (trimmed == "で" || trimmed == "だ") && stem.count >= 2 && "んい".contains(stem[stem.count - 1]) && Furigana.isKanji(stem[stem.count - 2])
            if fixed == nil, let last = words.last, last.fixed == nil, last.punct.isEmpty, glue.contains(trimmed) || teDe {
                words[words.count - 1].kana += kana
            } else {
                words.append(Word(kana: kana, fixed: fixed))
            }
            prevSurface = trimmed
        }
        guard cursor == ja.count, !words.isEmpty else { return nil }
        return words.map { ($0.fixed ?? Romaji.from($0.kana)) + $0.punct }.joined(separator: " ")
    }

    private static func simpleRomaji(_ ja: String, _ kana: String) -> String {
        let segs = segments(ja, kana)
        let particles: [String: String] = ["を": "お", "は": "わ", "へ": "え", "が": "が", "に": "に", "で": "で", "と": "と", "も": "も", "の": "の"]
        func isWordEnd(_ s: Furigana.Seg) -> Bool {
            s.ruby != nil || s.base.unicodeScalars.allSatisfy { (0x30A1...0x30FA).contains($0.value) || $0.value == 0x30FC }
        }
        func isWordStart(_ s: Furigana.Seg?) -> Bool {
            guard let s else { return true }
            if s.ruby != nil || "、。，．！？".contains(s.base) { return true }
            return s.base.unicodeScalars.allSatisfy { (0x30A1...0x30FA).contains($0.value) }
        }
        var out = ""
        for (i, s) in segs.enumerated() {
            if s.ruby == nil, let p = particles[s.base], i > 0, isWordEnd(segs[i - 1]), isWordStart(i + 1 < segs.count ? segs[i + 1] : nil) {
                out += " \(p) "
            } else {
                out += s.ruby ?? KanaData.toHiragana(s.base)
            }
        }
        return Romaji.from(out)
    }

    /// Reading of a substring (by character offsets) of `ja`.
    static func reading(of sub: Range<String.Index>, in ja: String, kana: String) -> String {
        let lo = ja.distance(from: ja.startIndex, to: sub.lowerBound)
        let hi = ja.distance(from: ja.startIndex, to: sub.upperBound)
        var pos = 0, out = ""
        for s in segments(ja, kana) {
            let start = pos
            pos += s.base.count
            if start >= lo && start < hi { out += s.ruby ?? KanaData.toHiragana(s.base) }
        }
        return out
    }
}

// MARK: - Wrapping layout for ruby segments

struct RubyFlow: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 4
    var center = false

    private func rows(_ subviews: Subviews, maxW: CGFloat) -> [[(Int, CGSize)]] {
        var rows: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            var s = v.sizeThatFits(.unspecified)
            if s.width > maxW { s = v.sizeThatFits(ProposedViewSize(width: maxW, height: nil)) }   // long Thai phrase: let it wrap inside
            if x > 0, x + s.width > maxW { rows.append([]); x = 0 }
            rows[rows.count - 1].append((i, s))
            x += s.width + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        let rs = rows(subviews, maxW: maxW)
        let widest = rs.map { r in r.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, r.count - 1)) }.max() ?? 0
        let height = rs.reduce(0) { $0 + ($1.map(\.1.height).max() ?? 0) } + lineSpacing * CGFloat(max(0, rs.count - 1))
        return CGSize(width: min(widest, maxW), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for r in rows(subviews, maxW: bounds.width) {
            let rowW = r.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, r.count - 1))
            let rowH = r.map(\.1.height).max() ?? 0
            var x = bounds.minX + (center ? max(0, (bounds.width - rowW) / 2) : 0)
            for (i, s) in r {
                // Bottom-align so Latin words sit on the Japanese baseline row.
                subviews[i].place(at: CGPoint(x: x, y: y + rowH - s.height), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rowH + lineSpacing
        }
    }
}

// MARK: - JPText

/// Every Japanese string in the app goes through this: furigana sits over its
/// own kanji when ふ is on, romaji appears underneath when A is on. Pass
/// `furigana:` / `romaji:` to override (e.g. quizzes that test the reading).
struct JPText: View {
    @Environment(ProgressStore.self) private var store
    let ja: String
    let kana: String
    var size: CGFloat = 20
    var bold = false
    var color: Color = Ink.ink
    var highlight: String? = nil          // substring drawn in akane
    var furigana: Bool? = nil
    var romaji: Bool? = nil
    var alignment: HorizontalAlignment = .leading
    var romajiText: String? = nil         // better spaced romaji from the data, when we have it
    var highlights: [String] = []         // several substrings in akane (drill slots)

    var body: some View {
        let showRuby = (furigana ?? store.settings.showFurigana) && !kana.isEmpty && ja.contains(where: Furigana.isKanji)
        let showRomaji = (romaji ?? store.settings.showRomaji) && !kana.isEmpty
        let segs = Furigana.segments(ja, kana)
        let hl = highlightRanges
        VStack(alignment: alignment, spacing: 2) {
            RubyFlow(spacing: 0, lineSpacing: showRuby ? 2 : 4) {
                ForEach(Array(offsets(segs).enumerated()), id: \.offset) { _, item in
                    let (seg, start) = item
                    let on = hl.contains { start >= $0.lowerBound && start < $0.upperBound }
                    VStack(spacing: 0) {
                        if showRuby {
                            Text(seg.ruby ?? " ").font(Typo.ui(max(9, size * 0.42), .medium))
                                .foregroundStyle(on ? Ink.akane : Ink.soft)
                                .lineLimit(1).fixedSize()
                                .opacity(seg.ruby == nil ? 0 : 1)
                        }
                        Text(seg.base).font(Typo.mincho(size, bold: bold))
                            .foregroundStyle(on ? Ink.akane : color)
                            .overlay(alignment: .bottom) { if on { Rectangle().fill(Ink.akane).frame(height: max(1, size * 0.06)).offset(y: 2) } }
                            .fixedSize()
                    }
                    .frame(minWidth: showRuby ? segWidth(seg) : 0, alignment: .center)
                }
            }
            if showRomaji {
                Text((romajiText?.isEmpty == false ? romajiText! : Furigana.romaji(ja, kana))).font(Typo.ui(max(10, size * 0.5))).foregroundStyle(Ink.soft)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ja)
    }

    private var highlightRanges: [Range<Int>] {
        var out: [Range<Int>] = []
        var from = ja.startIndex
        for h in ([highlight].compactMap { $0 } + highlights) where !h.isEmpty {
            // Slots appear in order; search after the previous one, then from the start.
            guard let r = ja.range(of: h, range: from..<ja.endIndex) ?? ja.range(of: h) else { continue }
            let lo = ja.distance(from: ja.startIndex, to: r.lowerBound)
            out.append(lo..<(lo + h.count))
            from = r.upperBound
        }
        return out
    }

    private func offsets(_ segs: [Furigana.Seg]) -> [(Furigana.Seg, Int)] {
        var pos = 0
        return segs.map { s in defer { pos += s.base.count }; return (s, pos) }
    }

    /// Let a long reading widen its base slightly so readings don't collide.
    private func segWidth(_ s: Furigana.Seg) -> CGFloat {
        guard let r = s.ruby else { return 0 }
        return max(CGFloat(s.base.count) * size, CGFloat(r.count) * size * 0.42)
    }
}

// MARK: - Automatic readings for Japanese without stored kana
// Grammar notes, explanations and essentials mix English/Thai with Japanese
// (e.g. "Don't use は with question words — 誰が来ますか"). The system's Japanese
// tokenizer gives each word a Latin transcription, which we turn back into
// hiragana and align to the kanji.

enum AutoReading {
    struct Token: Hashable {
        let surface: String
        let kana: String?          // nil when the token has no kanji (no reading needed)
        let romaji: String
    }

    nonisolated(unsafe) private static var cache: [String: [Token]] = [:]

    /// Learner readings that beat the system analyzer: the course vocab's kanji
    /// compounds, plus numbers × counters, times and dates.
    static let lexicon: [String: String] = {
        var d: [String: String] = [:]
        for v in DB.shared.vocab where v.kanji.count >= 2 && !v.kanji.contains("〜")
            && v.kanji.allSatisfy(Furigana.isKanji) && v.kana.allSatisfy({ !Furigana.isKanji($0) }) {
            d[v.kanji] = v.kana.replacingOccurrences(of: "〜", with: "")
        }
        let nums = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        let counters: [String: [String]] = [
            "本": ["いっぽん", "にほん", "さんぼん", "よんほん", "ごほん", "ろっぽん", "ななほん", "はっぽん", "きゅうほん", "じゅっぽん"],
            "匹": ["いっぴき", "にひき", "さんびき", "よんひき", "ごひき", "ろっぴき", "ななひき", "はっぴき", "きゅうひき", "じゅっぴき"],
            "杯": ["いっぱい", "にはい", "さんばい", "よんはい", "ごはい", "ろっぱい", "ななはい", "はっぱい", "きゅうはい", "じゅっぱい"],
            "人": ["ひとり", "ふたり", "さんにん", "よにん", "ごにん", "ろくにん", "ななにん", "はちにん", "きゅうにん", "じゅうにん"],
            "時": ["いちじ", "にじ", "さんじ", "よじ", "ごじ", "ろくじ", "しちじ", "はちじ", "くじ", "じゅうじ"],
            "枚": ["いちまい", "にまい", "さんまい", "よんまい", "ごまい", "ろくまい", "ななまい", "はちまい", "きゅうまい", "じゅうまい"],
            "分": ["いっぷん", "にふん", "さんぷん", "よんぷん", "ごふん", "ろっぷん", "ななふん", "はっぷん", "きゅうふん", "じゅっぷん"],
            "月": ["いちがつ", "にがつ", "さんがつ", "しがつ", "ごがつ", "ろくがつ", "しちがつ", "はちがつ", "くがつ", "じゅうがつ"],
            "日": ["ついたち", "ふつか", "みっか", "よっか", "いつか", "むいか", "なのか", "ようか", "ここのか", "とおか"],
            "つ": ["ひとつ", "ふたつ", "みっつ", "よっつ", "いつつ", "むっつ", "ななつ", "やっつ", "ここのつ", "とお"]
        ]
        for (c, rs) in counters { for (i, r) in rs.enumerated() { d[nums[i] + c] = r } }
        let extra = ["私": "わたし", "日本": "にほん", "日本語": "にほんご", "日本人": "にほんじん", "今日": "きょう", "明日": "あした", "昨日": "きのう",
                     "今年": "ことし", "大人": "おとな", "上手": "じょうず", "下手": "へた", "一人": "ひとり", "二人": "ふたり", "二十日": "はつか",
                     "何時": "なんじ", "何人": "なんにん", "何本": "なんぼん", "何匹": "なんびき", "何曜日": "なんようび", "十一時": "じゅういちじ", "十二時": "じゅうにじ"]
        for (k, v) in extra { d[k] = v }
        // Grammar terms used in lesson notes.
        let terms = ["辞書形": "じしょけい", "普通形": "ふつうけい", "可能形": "かのうけい", "命令形": "めいれいけい", "意向形": "いこうけい",
                     "受身形": "うけみけい", "使役形": "しえきけい", "丁寧形": "ていねいけい", "禁止形": "きんしけい", "条件形": "じょうけんけい",
                     "尊敬語": "そんけいご", "謙譲語": "けんじょうご", "丁寧語": "ていねいご", "敬語": "けいご", "自動詞": "じどうし", "他動詞": "たどうし",
                     "形容詞": "けいようし", "名詞": "めいし", "動詞": "どうし", "助詞": "じょし", "文型": "ぶんけい", "例文": "れいぶん", "文法": "ぶんぽう",
                     "語順": "ごじゅん", "一歩": "いっぽ", "疑問詞": "ぎもんし", "受身": "うけみ", "使役": "しえき", "語彙": "ごい", "会話": "かいわ"]
        for (k, v) in terms { d[k] = v }
        return d
    }()

    private static let particles: [Character: String] = ["は": "wa", "が": "ga", "を": "o", "に": "ni", "で": "de", "も": "mo", "へ": "e", "と": "to", "の": "no"]

    static func tokens(_ japanese: String) -> [Token] {
        if let hit = cache[japanese] { return hit }
        // Longest lexicon match first; the system analyzer reads the gaps.
        var out: [Token] = []
        let chars = Array(japanese)
        var gap = ""
        var i = 0
        while i < chars.count {
            var matched = false
            // 形 right after kana is the grammar suffix: て形, ます形, ない形 → けい.
            if chars[i] == "形", i > 0, !Furigana.isKanji(chars[i - 1]), ("\u{3041}"..."\u{30FA}").contains(chars[i - 1]) {
                out += systemTokens(gap, previous: out.last); gap = ""
                out.append(Token(surface: "形", kana: "けい", romaji: "kei"))
                i += 1; continue
            }
            if Furigana.isKanji(chars[i]) {
                for len in stride(from: min(5, chars.count - i), through: 1, by: -1) {
                    let w = String(chars[i..<(i + len)])
                    if let k = lexicon[w] {
                        out += systemTokens(gap, previous: out.last); gap = ""
                        out.append(Token(surface: w, kana: k, romaji: Romaji.from(k)))
                        i += len; matched = true; break
                    }
                }
                if matched {
                    // A particle right after a known word stands alone, so the analyzer
                    // can't read 今日|はいい as "hai i" (but です / でした stay whole).
                    if i < chars.count, let p = Self.particles[chars[i]],
                       !(chars[i] == "で" && i + 1 < chars.count && "しす".contains(chars[i + 1])) {
                        out.append(Token(surface: String(chars[i]), kana: nil, romaji: p))
                        i += 1
                    }
                    continue
                }
            }
            if !matched { gap.append(chars[i]); i += 1 }
        }
        out += systemTokens(gap, previous: out.last)
        // A token ending in small っ (行っ|た, 買っ|て) joins the next one so it romanises as "itta".
        var merged: [Token] = []
        for t in out {
            if let last = merged.last, last.surface.hasSuffix("っ") || last.surface.hasSuffix("ッ"),
               t.surface.unicodeScalars.first.map({ (0x3041...0x30FA).contains($0.value) || $0.properties.isIdeographic }) == true {
                let k1 = last.kana ?? KanaData.toHiragana(last.surface), k2 = t.kana ?? KanaData.toHiragana(t.surface)
                let hasKanji = last.kana != nil || t.kana != nil
                merged[merged.count - 1] = Token(surface: last.surface + t.surface, kana: hasKanji ? k1 + k2 : nil, romaji: Romaji.from(k1 + k2))
            } else {
                merged.append(t)
            }
        }
        out = merged
        cache[japanese] = out
        return out
    }

    private static func systemTokens(_ japanese: String, previous: Token?) -> [Token] {
        guard !japanese.isEmpty else { return [] }
        let ns = japanese as NSString
        let tok = CFStringTokenizerCreate(nil, japanese as CFString, CFRange(location: 0, length: ns.length),
                                          kCFStringTokenizerUnitWordBoundary, Locale(identifier: "ja") as CFLocale)
        var out: [Token] = []
        var cursor = 0
        var type = CFStringTokenizerAdvanceToNextToken(tok)
        while type != [] {
            let r = CFStringTokenizerGetCurrentTokenRange(tok)
            if r.location > cursor { out += plain(ns.substring(with: NSRange(location: cursor, length: r.location - cursor))) }
            let surface = ns.substring(with: NSRange(location: r.location, length: r.length))
            let latin = CFStringTokenizerCopyCurrentTokenAttribute(tok, kCFStringTokenizerAttributeLatinTranscription) as? String ?? ""
            out.append(make(surface, latin: latin, previous: out.last ?? previous))
            cursor = r.location + r.length
            type = CFStringTokenizerAdvanceToNextToken(tok)
        }
        if cursor < ns.length { out += plain(ns.substring(from: cursor)) }
        return out
    }

    private static func plain(_ s: String) -> [Token] {
        s.isEmpty ? [] : [Token(surface: s, kana: nil, romaji: "")]
    }

    private static func make(_ surface: String, latin: String, previous: Token?) -> Token {
        let hasKanji = surface.contains(where: Furigana.isKanji)
        var kana: String? = nil
        if hasKanji, !latin.isEmpty {
            let m = NSMutableString(string: latin)
            CFStringTransform(m, nil, kCFStringTransformLatinHiragana, false)
            kana = String(m)
        }
        // Particles read differently from how they're written.
        let roma: String
        switch surface {
        case "は" where previous != nil: roma = "wa"
        case "へ" where previous != nil: roma = "e"
        case "を": roma = "o"
        case "こんにちは": roma = "konnichiwa"
        case "こんばんは": roma = "konbanwa"
        default: roma = latin.isEmpty ? Romaji.from(surface) : latin
        }
        return Token(surface: surface, kana: kana, romaji: roma)
    }
}

// MARK: - MixedText: English/Thai with Japanese inside

enum Mixed {
    enum Piece: Hashable {
        case text(String)                       // a Latin/Thai word (with its trailing space)
        case jp([Furigana.Seg], String)         // one Japanese token: segments + romaji
    }

    static func isJP(_ c: Character) -> Bool {
        guard let v = c.unicodeScalars.first?.value else { return false }
        return (0x3040...0x30FF).contains(v) || (0x3000...0x303F).contains(v) || (0xFF01...0xFF5E).contains(v) && !("０"..."９").contains(c)
            || Furigana.isKanji(c) || c == "〜"
    }

    static func hasJapanese(_ s: String) -> Bool { s.contains { isJP($0) && $0 != "　" } }

    nonisolated(unsafe) private static var cache: [String: [Piece]] = [:]

    static func pieces(_ s: String) -> [Piece] {
        if let hit = cache[s] { return hit }
        var out: [Piece] = []
        var run = "", runJP = false
        func flush() {
            guard !run.isEmpty else { return }
            if runJP, run == "は" || run == "へ" || run == "を" {
                // The particle mentioned on its own inside English/Thai text.
                out.append(.jp([Furigana.Seg(base: run, ruby: nil)], ["は": "wa", "へ": "e", "を": "o"][run]!))
            } else if runJP {
                for t in AutoReading.tokens(run) {
                    let segs = t.kana.map { Furigana.segments(t.surface, $0) } ?? [Furigana.Seg(base: t.surface, ruby: nil)]
                    out.append(.jp(segs, t.kana == nil && !t.surface.contains(where: { $0.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) } }) ? "" : t.romaji))
                }
            } else {
                // Keep spaces attached so lines wrap between words.
                var word = ""
                for ch in run {
                    word.append(ch)
                    if ch == " " { out.append(.text(word)); word = "" }
                }
                if !word.isEmpty { out.append(.text(word)) }
            }
            run = ""
        }
        for ch in s {
            let jp = isJP(ch)
            if jp != runJP { flush(); runJP = jp }
            run.append(ch)
        }
        flush()
        cache[s] = out
        return out
    }
}

/// Any UI string that may contain Japanese. Plain text when it has none;
/// otherwise the Japanese gets furigana over kanji (ふ) and romaji below (A).
struct MixedText: View {
    @Environment(ProgressStore.self) private var store
    let text: String
    var size: CGFloat = 14
    var weight: Font.Weight = .regular
    var color: Color = Ink.ink
    var center = false
    var furigana: Bool? = nil
    var romaji: Bool? = nil

    init(_ text: String, size: CGFloat = 14, weight: Font.Weight = .regular, color: Color = Ink.ink, center: Bool = false, furigana: Bool? = nil, romaji: Bool? = nil) {
        self.text = text; self.size = size; self.weight = weight; self.color = color; self.center = center
        self.furigana = furigana; self.romaji = romaji
    }

    var body: some View {
        let ruby = furigana ?? store.settings.showFurigana
        let roma = romaji ?? store.settings.showRomaji
        if !Mixed.hasJapanese(text) || (!ruby && !roma) {
            Text(text).font(Typo.ui(size, weight)).foregroundStyle(color)
                .multilineTextAlignment(center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let pieces = Mixed.pieces(text)
            let anyKanji = text.contains(where: Furigana.isKanji)
            RubyFlow(spacing: 0, lineSpacing: 3, center: center) {
                ForEach(Array(pieces.enumerated()), id: \.offset) { _, p in
                    switch p {
                    case .text(let w):
                        VStack(spacing: 0) {
                            if ruby && anyKanji { Text(" ").font(Typo.ui(size * 0.5)) }
                            Text(w).font(Typo.ui(size, weight)).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
                            if roma { Text(" ").font(Typo.ui(size * 0.6)) }
                        }
                    case .jp(let segs, let r):
                        VStack(spacing: 0) {
                            HStack(alignment: .bottom, spacing: 0) {
                                ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                                    VStack(spacing: 0) {
                                        if ruby && anyKanji {
                                            Text(seg.ruby ?? " ").font(Typo.ui(size * 0.5, .medium)).foregroundStyle(Ink.soft)
                                                .opacity(seg.ruby == nil ? 0 : 1).lineLimit(1).fixedSize()
                                        }
                                        Text(seg.base).font(Typo.mincho(size * 1.05, bold: weight != .regular)).foregroundStyle(color).fixedSize()
                                    }
                                }
                            }
                            if roma { Text(r.isEmpty ? " " : r).font(Typo.ui(size * 0.6)).foregroundStyle(Ink.soft).lineLimit(1).fixedSize() }
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
        }
    }
}
