import Foundation

enum CardKind: String, Codable, CaseIterable {
    case vocab, kanji, grammar, kana
    var ja: String {
        switch self { case .vocab: "語彙"; case .kanji: "漢字"; case .grammar: "文法"; case .kana: "かな" }
    }
    var en: String {
        switch self { case .vocab: "Vocab"; case .kanji: "Kanji"; case .grammar: "Grammar"; case .kana: "Kana" }
    }
}

/// One flashcard — a thin wrapper over the content item so the study and quiz
/// engines treat every kind the same way. Identity is the string id, which is
/// what progress is keyed on ("v:食べる_たべる", "k:食", "g:n5.e.tai", "h:あ").
struct Card: Identifiable, Hashable {
    enum Payload {
        case vocab(Vocab), kanji(KanjiItem), grammar(GrammarItem), kana(KanaItem)
    }

    let id: String
    let payload: Payload

    static func vocab(_ v: Vocab) -> Card { Card(id: "v:" + v.id, payload: .vocab(v)) }
    static func kanji(_ k: KanjiItem) -> Card { Card(id: "k:" + k.id, payload: .kanji(k)) }
    static func grammar(_ g: GrammarItem) -> Card { Card(id: "g:" + g.key, payload: .grammar(g)) }
    static func kana(_ k: KanaItem) -> Card { Card(id: k.id, payload: .kana(k)) }

    static func == (a: Card, b: Card) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var kind: CardKind {
        switch payload { case .vocab: .vocab; case .kanji: .kanji; case .grammar: .grammar; case .kana: .kana }
    }

    var level: Level? {
        switch payload {
        case .vocab(let v): v.level
        case .kanji(let k): k.level
        case .grammar(let g): g.level
        case .kana: nil
        }
    }

    /// Main text on the front.
    var prompt: String {
        switch payload {
        case .vocab(let v): v.word
        case .kanji(let k): k.char
        case .grammar(let g): g.pattern
        case .kana(let k): k.char
        }
    }

    /// Kana reading (empty for grammar).
    var reading: String {
        switch payload {
        case .vocab(let v): v.kana
        case .kanji(let k): k.reading
        case .grammar: ""
        case .kana(let k): k.romaji
        }
    }

    var romaji: String {
        switch payload {
        case .vocab(let v): v.romaji
        case .kanji(let k): k.romaji
        case .grammar: ""
        case .kana(let k): k.romaji
        }
    }

    /// Thai meaning — the primary gloss everywhere.
    var meaning: String {
        switch payload {
        case .vocab(let v): v.th
        case .kanji(let k): k.th
        case .grammar(let g): g.th
        case .kana(let k): k.romaji
        }
    }

    var meaningEN: String {
        switch payload {
        case .vocab: ""
        case .kanji(let k): k.en
        case .grammar(let g): g.en
        case .kana: ""
        }
    }

    /// Text to hand to the speech synthesizer.
    var speech: String {
        switch payload {
        case .vocab(let v): v.kana.replacingOccurrences(of: "〜", with: "")
        case .kanji(let k): k.reading
        case .grammar(let g): g.examples.first?.kana ?? g.pattern
        case .kana(let k): k.char
        }
    }

    var badge: String {
        switch payload {
        case .vocab(let v): v.posLabel
        case .kanji(let k): "KANJI · \(k.strokes)画"
        case .grammar: "GRAMMAR · 文法"
        case .kana(let k): k.script == .hira ? "HIRAGANA · ひらがな" : "KATAKANA · カタカナ"
        }
    }

    var searchText: String {
        switch payload {
        case .vocab(let v): "\(v.kanji) \(v.kana) \(v.romaji) \(v.th)".lowercased()
        case .kanji(let k): "\(k.char) \(k.on) \(k.kun) \(k.th) \(k.en) \(k.romaji)".lowercased()
        case .grammar(let g): "\(g.pattern) \(g.th) \(g.en) \(g.structure)".lowercased()
        case .kana(let k): "\(k.char) \(k.romaji)".lowercased()
        }
    }

    func exactMatch(_ q: String) -> Bool {
        prompt.lowercased() == q || reading.lowercased() == q || romaji.lowercased() == q
    }

    var vocab: Vocab? { if case .vocab(let v) = payload { v } else { nil } }
    var kanjiItem: KanjiItem? { if case .kanji(let k) = payload { k } else { nil } }
    var grammarItem: GrammarItem? { if case .grammar(let g) = payload { g } else { nil } }
    var kanaItem: KanaItem? { if case .kana(let k) = payload { k } else { nil } }
}
