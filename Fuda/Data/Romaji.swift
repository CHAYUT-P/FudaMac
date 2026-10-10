import Foundation

/// Minimal Hepburn romanisation for kana text (hiragana or katakana).
enum Romaji {
    private static let base: [Character: String] = {
        let pairs: [(String, String)] = [
            ("あ","a"),("い","i"),("う","u"),("え","e"),("お","o"),
            ("か","ka"),("き","ki"),("く","ku"),("け","ke"),("こ","ko"),
            ("が","ga"),("ぎ","gi"),("ぐ","gu"),("げ","ge"),("ご","go"),
            ("さ","sa"),("し","shi"),("す","su"),("せ","se"),("そ","so"),
            ("ざ","za"),("じ","ji"),("ず","zu"),("ぜ","ze"),("ぞ","zo"),
            ("た","ta"),("ち","chi"),("つ","tsu"),("て","te"),("と","to"),
            ("だ","da"),("ぢ","ji"),("づ","zu"),("で","de"),("ど","do"),
            ("な","na"),("に","ni"),("ぬ","nu"),("ね","ne"),("の","no"),
            ("は","ha"),("ひ","hi"),("ふ","fu"),("へ","he"),("ほ","ho"),
            ("ば","ba"),("び","bi"),("ぶ","bu"),("べ","be"),("ぼ","bo"),
            ("ぱ","pa"),("ぴ","pi"),("ぷ","pu"),("ぺ","pe"),("ぽ","po"),
            ("ま","ma"),("み","mi"),("む","mu"),("め","me"),("も","mo"),
            ("や","ya"),("ゆ","yu"),("よ","yo"),
            ("ら","ra"),("り","ri"),("る","ru"),("れ","re"),("ろ","ro"),
            ("わ","wa"),("を","o"),("ん","n"),("ゔ","vu"),
            ("ぁ","a"),("ぃ","i"),("ぅ","u"),("ぇ","e"),("ぉ","o"),
            ("、",", "),("。",". "),("！","! "),("？","? "),("…","… "),("・"," "),("「","\""),("」","\""),
        ]
        return Dictionary(uniqueKeysWithValues: pairs.map { (Character($0.0), $0.1) })
    }()

    private static let smallY: [Character: String] = ["ゃ": "a", "ゅ": "u", "ょ": "o"]
    private static let smallV: [Character: String] = ["ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o"]

    static func from(_ text: String) -> String {
        let chars = Array(KanaData.toHiragana(text))
        var out = ""
        var i = 0
        var doubleNext = false
        while i < chars.count {
            let c = chars[i]
            if c == "っ" { doubleNext = true; i += 1; continue }
            if c == "ー" { if let last = out.last, "aeiou".contains(last) { out.append(last) }; i += 1; continue }
            var syl: String
            if let b = base[c] {
                syl = b
                if i + 1 < chars.count, let y = smallY[chars[i + 1]], b.count >= 2 {
                    // きゃ → kya, しゃ → sha, ちゃ → cha, じゃ → ja
                    let stem = String(b.dropLast())
                    syl = (stem == "sh" || stem == "ch" || stem == "j") ? stem + y : stem + "y" + y
                    i += 1
                } else if i + 1 < chars.count, let v = smallV[chars[i + 1]], b.count >= 2 {
                    // ティ → ti, ファ → fa
                    syl = String(b.dropLast()) + v
                    i += 1
                }
            } else {
                syl = String(c)
            }
            if doubleNext, let f = syl.first, f.isLetter {
                out += syl.hasPrefix("ch") ? "t" : String(f)
            }
            doubleNext = false
            if syl == "n", i + 1 < chars.count, let nb = base[chars[i + 1]], let f = nb.first, "aeiouy".contains(f) {
                syl = "n'"
            }
            out += syl
            i += 1
        }
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }
}

extension KanaData {
    static func toHiragana(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { u in
            (0x30A1...0x30F6).contains(u.value) ? Unicode.Scalar(u.value - 0x60)! : u
        }))
    }
}

// MARK: - Romaji → hiragana (for typed answers)

extension Romaji {
    /// Vowel a kana ends in ("か" → "a", "ゃ" → "a"), used to spell out ー.
    static func vowel(of c: Character) -> Character? {
        let h = Character(KanaData.toHiragana(String(c)))
        if let y = smallY[h] { return y.first }
        guard let r = base[h], let last = r.last, "aeiou".contains(last) else { return nil }
        return last
    }

    private static let toKana: [String: String] = {
        var t: [String: String] = [
            "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
            "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
            "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
            "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
            "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
            "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
            "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
            "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
            "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
            "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
            "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
            "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
            "ya": "や", "yu": "ゆ", "yo": "よ",
            "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
            "la": "ら", "li": "り", "lu": "る", "le": "れ", "lo": "ろ",
            "wa": "わ", "wo": "を", "wi": "うぃ", "we": "うぇ",
            "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
            "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
            "ja": "じゃ", "ju": "じゅ", "je": "じぇ", "jo": "じょ",
            "sha": "しゃ", "shu": "しゅ", "she": "しぇ", "sho": "しょ",
            "cha": "ちゃ", "chu": "ちゅ", "che": "ちぇ", "cho": "ちょ",
            "thi": "てぃ", "dhi": "でぃ", "tsa": "つぁ",
            "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ", "xtu": "っ", "ltu": "っ",
            "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ", "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ",
        ]
        // Contracted sounds: kya, nyu, ryo … plus the j / sh / ch spellings typed as jya, sya, tya, cya.
        let rows: [(String, String)] = [("k", "き"), ("g", "ぎ"), ("n", "に"), ("h", "ひ"), ("b", "び"), ("p", "ぴ"),
                                        ("m", "み"), ("r", "り"), ("s", "し"), ("z", "じ"), ("j", "じ"), ("t", "ち"), ("c", "ち"), ("d", "ぢ")]
        for (c, k) in rows {
            for (v, small) in [("a", "ゃ"), ("u", "ゅ"), ("o", "ょ")] { t[c + "y" + v] = k + small }
        }
        return t
    }()

    /// "koohii" → "こおひい", "konnichiwa" → "こんにちわ", "gakkou" → "がっこう". Non-romaji passes through.
    /// `imeStyle`: "nn" is always ん, as on a Japanese keyboard ("gennin" → げんいん);
    /// otherwise Hepburn ("konnichiwa" → こんにちわ).
    static func toHiragana(_ input: String, imeStyle: Bool = false) -> String {
        var s = input.lowercased().replacingOccurrences(of: "’", with: "'")
        for (m, r) in [("ā", "aa"), ("ī", "ii"), ("ū", "uu"), ("ē", "ee"), ("ō", "ou"), ("ô", "ou"), ("â", "aa"), ("û", "uu")] {
            s = s.replacingOccurrences(of: m, with: r)
        }
        let c = Array(s)
        let vowels: Set<Character> = ["a", "i", "u", "e", "o"]
        var out = ""
        var i = 0
        while i < c.count {
            let ch = c[i]
            let next: Character? = i + 1 < c.count ? c[i + 1] : nil
            if ch == "-" || ch == "ー" { out += "ー"; i += 1; continue }
            if ch == "n" {
                if next == "'" { out += "ん"; i += 2; continue }
                if next == "n" {
                    let after: Character? = i + 2 < c.count ? c[i + 2] : nil
                    if !imeStyle, let a = after, vowels.contains(a) || a == "y" { out += "ん"; i += 1 } else { out += "ん"; i += 2 }
                    continue
                }
                if next == nil || !(vowels.contains(next!) || next == "y") { out += "ん"; i += 1; continue }
            }
            // Doubled consonant → っ (kk, tt, ss, pp …; "tch" as in matcha).
            if let n = next, ch.isLetter, !vowels.contains(ch), ch != "n", n == ch || (ch == "t" && n == "c") {
                out += "っ"; i += 1; continue
            }
            var matched = false
            for len in [3, 2, 1] where i + len <= c.count {
                if let k = toKana[String(c[i..<(i + len)])] { out += k; i += len; matched = true; break }
            }
            if !matched { out.append(ch); i += 1 }
        }
        return out
    }
}
