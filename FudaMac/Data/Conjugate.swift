import Foundation

/// Small verb conjugator for card backs: dictionary → ます / て / た / ない /
/// potential. Groups: する・来る irregular; る after an い/え-row sound is
/// Group 2 unless it's one of the common Group 1 look-alikes.
enum Conjugate {
    enum Group: Int { case godan = 1, ichidan = 2, irregular = 3 }

    struct Forms { let group: Group; let rows: [(String, String, String)] }   // (name, form, lesson)

    private static let godanRu: Set<String> = ["帰る", "入る", "走る", "知る", "要る", "切る", "減る", "滑る", "喋る", "参る", "限る", "かえる", "はいる", "はしる", "しる"]
    private static let iRow: Set<Character> = Set("いきぎしじちぢにひびぴみりえけげせぜてでねへべぺめれ")

    static func group(_ word: String, kana: String) -> Group? {
        let w = word.replacingOccurrences(of: "〜", with: "")
        if w.hasSuffix("する") || w == "来る" || kana == "くる" { return .irregular }
        guard let last = kana.last, "うくぐすつぬぶむる".contains(last) else { return nil }
        if last == "る", godanRu.contains(w) == false, kana.count >= 2 {
            let prev = kana[kana.index(kana.endIndex, offsetBy: -2)]
            if iRow.contains(prev) { return .ichidan }
        }
        return .godan
    }

    static func forms(_ word: String, kana: String) -> Forms? {
        let w = word.replacingOccurrences(of: "〜", with: "")
        guard let g = group(w, kana: kana) else { return nil }
        let stem = String(w.dropLast())
        var rows: [(String, String, String)] = [("Dictionary", w, "L10")]
        switch g {
        case .irregular:
            if w.hasSuffix("する") {
                let base = String(w.dropLast(2))
                rows += [("ます form", base + "します", "L4"), ("て form", base + "して", "L8"), ("た form", base + "した", "L11"), ("ない form", base + "しない", "L9"), ("Potential", base + "できる", "N4")]
            } else {
                rows += [("ます form", "来ます (きます)", "L4"), ("て form", "来て (きて)", "L8"), ("た form", "来た (きた)", "L11"), ("ない form", "来ない (こない)", "L9"), ("Potential", "来られる", "N4")]
            }
        case .ichidan:
            rows += [("ます form", stem + "ます", "L4"), ("て form", stem + "て", "L8"), ("た form", stem + "た", "L11"), ("ない form", stem + "ない", "L9"), ("Potential", stem + "られる", "N4")]
        case .godan:
            let last = w.last!
            let i = shift(last, row: "い"), a = shift(last, row: "あ"), e = shift(last, row: "え")
            let te: String, ta: String
            switch last {
            case "う", "つ", "る": te = "って"; ta = "った"
            case "む", "ぶ", "ぬ": te = "んで"; ta = "んだ"
            case "く": te = w == "行く" ? "って" : "いて"; ta = w == "行く" ? "った" : "いた"
            case "ぐ": te = "いで"; ta = "いだ"
            default: te = "して"; ta = "した"
            }
            rows += [("ます form", stem + i + "ます", "L4"), ("て form", stem + te, "L8"), ("た form", stem + ta, "L11"),
                     ("ない form", stem + (last == "う" ? "わ" : a) + "ない", "L9"), ("Potential", stem + e + "る", "N4")]
        }
        return Forms(group: g, rows: rows)
    }

    private static func shift(_ c: Character, row: String) -> String {
        let table: [Character: [String: String]] = [
            "う": ["あ": "あ", "い": "い", "え": "え"], "く": ["あ": "か", "い": "き", "え": "け"], "ぐ": ["あ": "が", "い": "ぎ", "え": "げ"],
            "す": ["あ": "さ", "い": "し", "え": "せ"], "つ": ["あ": "た", "い": "ち", "え": "て"], "ぬ": ["あ": "な", "い": "に", "え": "ね"],
            "ぶ": ["あ": "ば", "い": "び", "え": "べ"], "む": ["あ": "ま", "い": "み", "え": "め"], "る": ["あ": "ら", "い": "り", "え": "れ"]
        ]
        return table[c]?[row] ?? String(c)
    }
}
