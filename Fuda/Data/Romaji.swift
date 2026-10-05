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
