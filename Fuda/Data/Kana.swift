import Foundation

struct KanaItem: Identifiable, Hashable {
    enum Script: String { case hira, kata }
    enum Group: String, CaseIterable { case base, dakuten, yoon }

    let id: String       // "h:あ" / "t:ア"
    let char: String
    let romaji: String
    let script: Script
    let group: Group
    let row: Int         // chart position (base: 0…10, col 0…4)
    let col: Int
}

enum KanaData {
    // Gojūon chart, row by row; "" = empty cell.
    private static let baseRows: [[(String, String)]] = [
        [("あ", "a"), ("い", "i"), ("う", "u"), ("え", "e"), ("お", "o")],
        [("か", "ka"), ("き", "ki"), ("く", "ku"), ("け", "ke"), ("こ", "ko")],
        [("さ", "sa"), ("し", "shi"), ("す", "su"), ("せ", "se"), ("そ", "so")],
        [("た", "ta"), ("ち", "chi"), ("つ", "tsu"), ("て", "te"), ("と", "to")],
        [("な", "na"), ("に", "ni"), ("ぬ", "nu"), ("ね", "ne"), ("の", "no")],
        [("は", "ha"), ("ひ", "hi"), ("ふ", "fu"), ("へ", "he"), ("ほ", "ho")],
        [("ま", "ma"), ("み", "mi"), ("む", "mu"), ("め", "me"), ("も", "mo")],
        [("や", "ya"), ("", ""), ("ゆ", "yu"), ("", ""), ("よ", "yo")],
        [("ら", "ra"), ("り", "ri"), ("る", "ru"), ("れ", "re"), ("ろ", "ro")],
        [("わ", "wa"), ("", ""), ("", ""), ("", ""), ("を", "wo")],
        [("ん", "n"), ("", ""), ("", ""), ("", ""), ("", "")],
    ]
    private static let dakutenRows: [[(String, String)]] = [
        [("が", "ga"), ("ぎ", "gi"), ("ぐ", "gu"), ("げ", "ge"), ("ご", "go")],
        [("ざ", "za"), ("じ", "ji"), ("ず", "zu"), ("ぜ", "ze"), ("ぞ", "zo")],
        [("だ", "da"), ("ぢ", "ji"), ("づ", "zu"), ("で", "de"), ("ど", "do")],
        [("ば", "ba"), ("び", "bi"), ("ぶ", "bu"), ("べ", "be"), ("ぼ", "bo")],
        [("ぱ", "pa"), ("ぴ", "pi"), ("ぷ", "pu"), ("ぺ", "pe"), ("ぽ", "po")],
    ]
    private static let yoonRows: [[(String, String)]] = [
        [("きゃ", "kya"), ("きゅ", "kyu"), ("きょ", "kyo")],
        [("しゃ", "sha"), ("しゅ", "shu"), ("しょ", "sho")],
        [("ちゃ", "cha"), ("ちゅ", "chu"), ("ちょ", "cho")],
        [("にゃ", "nya"), ("にゅ", "nyu"), ("にょ", "nyo")],
        [("ひゃ", "hya"), ("ひゅ", "hyu"), ("ひょ", "hyo")],
        [("みゃ", "mya"), ("みゅ", "myu"), ("みょ", "myo")],
        [("りゃ", "rya"), ("りゅ", "ryu"), ("りょ", "ryo")],
        [("ぎゃ", "gya"), ("ぎゅ", "gyu"), ("ぎょ", "gyo")],
        [("じゃ", "ja"), ("じゅ", "ju"), ("じょ", "jo")],
        [("びゃ", "bya"), ("びゅ", "byu"), ("びょ", "byo")],
        [("ぴゃ", "pya"), ("ぴゅ", "pyu"), ("ぴょ", "pyo")],
    ]

    static let all: [KanaItem] = KanaItem.Script.allScripts.flatMap { build($0) }

    static func items(_ script: KanaItem.Script, _ group: KanaItem.Group) -> [KanaItem] {
        all.filter { $0.script == script && $0.group == group }
    }

    /// Chart rows including blanks (nil) for layout.
    static func chart(_ script: KanaItem.Script, _ group: KanaItem.Group) -> [[KanaItem?]] {
        let rows: [[(String, String)]] = switch group { case .base: baseRows; case .dakuten: dakutenRows; case .yoon: yoonRows }
        let lookup = Dictionary(uniqueKeysWithValues: items(script, group).map { ($0.romaji + "|\($0.row)|\($0.col)", $0) })
        return rows.enumerated().map { r, row in
            row.enumerated().map { c, cell in cell.0.isEmpty ? nil : lookup[cell.1 + "|\(r)|\(c)"] }
        }
    }

    private static func build(_ script: KanaItem.Script) -> [KanaItem] {
        var out: [KanaItem] = []
        for (group, rows) in [(KanaItem.Group.base, baseRows), (.dakuten, dakutenRows), (.yoon, yoonRows)] {
            for (r, row) in rows.enumerated() {
                for (c, cell) in row.enumerated() where !cell.0.isEmpty {
                    let ch = script == .hira ? cell.0 : toKatakana(cell.0)
                    let prefix = script == .hira ? "h:" : "t:"
                    out.append(KanaItem(id: prefix + ch, char: ch, romaji: cell.1, script: script, group: group, row: r, col: c))
                }
            }
        }
        return out
    }

    static func toKatakana(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { u in
            (0x3041...0x3096).contains(u.value) ? Unicode.Scalar(u.value + 0x60)! : u
        }))
    }
}

extension KanaItem.Script {
    static let allScripts: [KanaItem.Script] = [.hira, .kata]
    var ja: String { self == .hira ? "ひらがな" : "カタカナ" }
    var en: String { self == .hira ? "Hiragana" : "Katakana" }
}

extension KanaItem.Group {
    var ja: String {
        switch self { case .base: "清音"; case .dakuten: "濁音"; case .yoon: "拗音" }
    }
    var en: String {
        switch self { case .base: "Basic 46"; case .dakuten: "Dakuten ゛゜"; case .yoon: "Combinations" }
    }
}
