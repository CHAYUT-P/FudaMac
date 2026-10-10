import Foundation

// The N5 + N4 word list: every word sorted into a theme and a subcategory,
// with English glosses and extra accepted Thai answers for typed checking.
// Built by Tools/wordlist/build_wordlist.py into Resources/wordlist.json.

struct WordSub: Codable, Identifiable, Hashable {
    let id: String          // "food.seasoning"
    let ja: String
    let th: String
    let en: String
}

struct WordCategory: Codable, Identifiable, Hashable {
    let id: String          // "food"
    let glyph: String
    let ja: String
    let th: String
    let en: String
    let subs: [WordSub]
}

struct WordMeta: Codable, Hashable {
    let sub: String
    let en: String
    var thAlt: [String] = []
    var also: [String] = []          // other spellings merged into this entry
    var more: [String] = []          // other subcategories it is also listed in (切る: hand actions + cooking)

    enum CodingKeys: String, CodingKey { case sub, en, thAlt, also, more }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        sub = try c.decode(String.self, forKey: .sub)
        en = try c.decode(String.self, forKey: .en)
        thAlt = try c.decodeIfPresent([String].self, forKey: .thAlt) ?? []
        also = try c.decodeIfPresent([String].self, forKey: .also) ?? []
        more = try c.decodeIfPresent([String].self, forKey: .more) ?? []
    }
}

struct ListWord: Identifiable, Hashable {
    let vocab: Vocab
    let meta: WordMeta
    var id: String { vocab.id }
    var cardID: String { "v:" + vocab.id }
    var level: Level { vocab.level }
    var isPlus: Bool { vocab.isPlus }
    var word: String { vocab.kanji }
    var kana: String { vocab.kana }
    var romaji: String { vocab.romaji }
    var th: String { vocab.th }
    var en: String { meta.en }
    /// Written only in kana (いろいろ, ジャム): the reading column adds nothing.
    var kanaOnly: Bool { KanaData.toHiragana(vocab.kanji) == KanaData.toHiragana(vocab.kana) }

    static func == (a: ListWord, b: ListWord) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

final class WordList {
    static let shared = WordList()

    let categories: [WordCategory]
    let referenceNote: String
    private(set) var bySub: [String: [ListWord]] = [:]
    private(set) var byCategory: [String: [ListWord]] = [:]
    private(set) var all: [ListWord] = []

    private struct File: Codable {
        let categories: [WordCategory]
        let words: [String: WordMeta]
        let reference: String
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "wordlist", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            assertionFailure("wordlist.json missing or invalid")
            categories = []; referenceNote = ""
            return
        }
        categories = file.categories
        referenceNote = file.reference
        // N5 first, then N4, then the everyday N4+ words — the order you learn them in.
        // Within a level keep the database order (N5 follows the course lessons).
        func rank(_ v: Vocab) -> Int { v.isPlus ? 2 : v.level == .n5 ? 0 : 1 }
        let ordered = DB.shared.vocab.enumerated().sorted { a, b in
            if rank(a.element) != rank(b.element) { return rank(a.element) < rank(b.element) }
            return a.offset < b.offset
        }.map(\.element)
        for v in ordered {
            guard let meta = file.words[v.id] else { continue }
            let w = ListWord(vocab: v, meta: meta)
            all.append(w)
            var cats: [String] = []
            for sub in [meta.sub] + meta.more {
                bySub[sub, default: []].append(w)
                let cat = String(sub.split(separator: ".").first ?? "")
                if !cats.contains(cat) { cats.append(cat); byCategory[cat, default: []].append(w) }
            }
        }
    }

    /// Words matching a search: kanji, kana, romaji (typed as romaji or kana), Thai or English.
    func search(_ query: String) -> [ListWord] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let kana = KanaData.toHiragana(q.contains(where: { $0.isASCII && $0.isLetter }) ? Romaji.toHiragana(q) : q)
        let isASCII = q.allSatisfy(\.isASCII)
        return all.filter { w in
            if w.word.contains(q) || w.meta.also.contains(where: { $0.contains(q) }) { return true }
            if !kana.isEmpty, KanaData.toHiragana(w.kana).replacingOccurrences(of: "〜", with: "").contains(kana) { return true }
            if isASCII, w.romaji.replacingOccurrences(of: " ", with: "").lowercased().contains(q.replacingOccurrences(of: " ", with: "")) { return true }
            if w.th.contains(q) || w.meta.thAlt.contains(where: { $0.contains(q) }) { return true }
            return isASCII && q.count >= 3 && w.en.lowercased().contains(q)
        }
    }

    func words(sub: String) -> [ListWord] { bySub[sub] ?? [] }
    func words(category: String) -> [ListWord] { byCategory[category] ?? [] }
    func category(of sub: String) -> WordCategory? { categories.first { $0.id == sub.split(separator: ".").first.map(String.init) } }
    func sub(_ id: String) -> WordSub? { categories.lazy.flatMap(\.subs).first { $0.id == id } }
}

// MARK: - Checking a typed meaning

enum MeaningCheck {
    /// Every answer we accept for a word: Thai variants, extra Thai answers, English variants.
    static func answers(_ w: ListWord) -> [String] {
        var out: [String] = []
        for part in splitVariants(w.th, separators: "/,;、") { out += thaiForms(part) }
        out += w.meta.thAlt.flatMap(thaiForms)
        out += splitVariants(w.en, separators: ";,/")
        return out.map(normalize).filter { !$0.isEmpty }
    }

    static func isCorrect(_ typed: String, _ w: ListWord) -> Bool {
        let t = normalize(typed)
        guard !t.isEmpty else { return false }
        return answers(w).contains { matches(t, $0) }
    }

    private static func splitVariants(_ s: String, separators: String) -> [String] {
        s.split(whereSeparator: { separators.contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "อาบ (น้ำฝักบัว)" accepts both "อาบ" and "อาบน้ำฝักบัว".
    private static func thaiForms(_ s: String) -> [String] {
        let without = s.replacingOccurrences(of: #"\s*[\(（][^\)）]*[\)）]"#, with: "", options: .regularExpression)
        let with = s.replacingOccurrences(of: #"[\(（\)）]"#, with: "", options: .regularExpression)
        return Array(Set([without, with].map { $0.trimmingCharacters(in: .whitespaces) }))
    }

    private static let stop: Set<String> = ["to", "a", "an", "the", "be", "is", "something", "someone", "sth", "sb", "one's"]

    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
            .replacingOccurrences(of: #"[\.\,\!\?\"'“”‘’…~〜～\-\(\)（）\[\]]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\u{200B}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if isThai(t) { t = t.replacingOccurrences(of: " ", with: "") }
        let words = t.split(separator: " ").map(String.init)
        let kept = words.filter { !stop.contains($0) }
        return (kept.isEmpty ? words : kept).joined(separator: " ")
    }

    private static func isThai(_ s: String) -> Bool { s.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) } }

    private static func matches(_ typed: String, _ answer: String) -> Bool {
        if typed == answer { return true }
        if isThai(typed) != isThai(answer) { return false }
        if isThai(typed) {
            // "สถานี" for "สถานีรถไฟ": part of the answer, at least half of it.
            let (short, long) = typed.count <= answer.count ? (typed, answer) : (answer, typed)
            if short.count >= 2, long.contains(short), short.count * 2 >= long.count { return true }
            return answer.count >= 4 && distance(typed, answer) <= 1
        }
        // English: same words (ignoring order of extras), or a small typo.
        let tw = Set(typed.split(separator: " ")), aw = Set(answer.split(separator: " "))
        if !aw.isEmpty, aw.isSubset(of: tw), tw.count <= aw.count + 1 { return true }
        if !tw.isEmpty, tw.isSubset(of: aw), tw.joined().count * 2 >= aw.joined().count { return true }
        let limit = answer.count >= 9 ? 2 : answer.count >= 5 ? 1 : 0
        return limit > 0 && distance(typed, answer) <= limit
    }

    /// Levenshtein distance over characters.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }
}

// MARK: - Checking typed Japanese (meaning → word)

enum JapaneseCheck {
    /// Right if it is the word as written (kanji or any listed spelling), or its
    /// reading typed in hiragana, katakana or romaji.
    static func isCorrect(_ typed: String, _ w: ListWord) -> Bool {
        let t = clean(halfwidth(typed))
        guard !t.isEmpty else { return false }

        // 1. Written form: 醤油, 醬油, お〜 / 御〜 (split), コーヒー …
        let surfaces = ([w.vocab.kanji] + w.meta.also).flatMap { $0.components(separatedBy: " / ") }.map(clean)
        if surfaces.contains(t) { return true }

        // 2. Reading: romaji is turned into kana first (Hepburn and keyboard-style "nn" both tried).
        let isRomaji = t.contains(where: { $0.isASCII && $0.isLetter })
        let typedKana = isRomaji ? [Romaji.toHiragana(t), Romaji.toHiragana(t, imeStyle: true)] : [KanaData.toHiragana(t)]
        let readings = [w.vocab.kana] + surfaces.filter { !$0.contains(where: { $0.unicodeScalars.contains { $0.properties.isIdeographic } }) }
        for kana in Set(typedKana) where !kana.contains(where: { $0.unicodeScalars.contains { $0.properties.isIdeographic } }) {
            if readings.contains(where: { key($0) == key(kana) }) { return true }
            // Same sound spelled the other way (とう/とお, せい/せえ, は/わ), or without the polite お/ご.
            if readings.contains(where: { looseKey($0) == looseKey(kana) }) { return true }
        }
        return false
    }

    /// Hiragana, no 〜 / spaces / punctuation, ー spelled out as its vowel.
    static func key(_ s: String) -> String {
        var out = ""
        for c in KanaData.toHiragana(clean(s)) where c != "'" {
            if c == "ー", let last = out.last, let v = Romaji.vowel(of: last) {
                out += String(v == "a" ? "あ" : v == "i" ? "い" : v == "u" ? "う" : v == "e" ? "え" : "お")
            } else {
                out.append(c)
            }
        }
        return out
    }

    private static func looseKey(_ s: String) -> String {
        var chars = Array(key(s))
        if chars.count > 2, chars.first == "お" || chars.first == "ご" { chars.removeFirst() }
        var out = ""
        for (i, c) in chars.enumerated() {
            let prev: Character? = i > 0 ? chars[i - 1] : nil
            let v = prev.flatMap(Romaji.vowel(of:))
            if c == "う", v == "o" { out += "お"; continue }       // とう → とお
            if c == "い", v == "e" { out += "え"; continue }       // せい → せえ
            out += c == "は" ? "わ" : c == "を" ? "お" : c == "へ" ? "え" : String(c)
        }
        return out
    }

    private static func clean(_ s: String) -> String {
        s.lowercased().filter { !"〜~～ 　・、。,.!?！？\"()（）".contains($0) }
    }

    /// Full-width ASCII from the Japanese keyboard (ｋａｎ) → normal letters.
    private static func halfwidth(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { u in
            (0xFF01...0xFF5E).contains(u.value) ? Unicode.Scalar(u.value - 0xFEE0)! : u
        }))
    }
}
