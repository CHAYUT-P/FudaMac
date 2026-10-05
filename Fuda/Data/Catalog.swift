import Foundation

// Library structure: Level → Shelf → Category → Sections → Cards.

enum Shelf: String, CaseIterable, Identifiable {
    case vocab, kanji, grammar, kana
    var id: String { rawValue }
    var kind: CardKind {
        switch self { case .vocab: .vocab; case .kanji: .kanji; case .grammar: .grammar; case .kana: .kana }
    }
}

enum VocabGrouping: String, CaseIterable, Identifiable {
    case lesson, type
    var id: String { rawValue }
}

struct DeckSection: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let cards: [Card]
}

struct Category: Identifiable, Hashable {
    let id: String
    let glyph: String
    let ja: String
    let en: String
    let caption: String      // e.g. "Lesson 4"
    let sections: [DeckSection]
    var kanjiPreview: [String] = []
    var cards: [Card] { sections.flatMap(\.cards) }

    static func == (a: Category, b: Category) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum Catalog {
    static let chunk = 20

    private static var cache: [String: [Category]] = [:]

    static func categories(_ shelf: Shelf, level: Level, grouping: VocabGrouping) -> [Category] {
        let key = "\(shelf.rawValue).\(level.rawValue).\(grouping.rawValue)"
        if let hit = cache[key] { return hit }
        let built = build(shelf, level: level, grouping: grouping)
        cache[key] = built
        return built
    }

    private static func build(_ shelf: Shelf, level: Level, grouping: VocabGrouping) -> [Category] {
        switch shelf {
        case .vocab: level == .n5 && grouping == .lesson ? buildLessons() : vocabByType(level)
        case .kanji: kanjiByTheme(level)
        case .grammar: grammarByCategory(level)
        case .kana: kana()
        }
    }

    private static let numerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二", "十三", "十四"]

    static func lessons() -> [Category] { categories(.vocab, level: .n5, grouping: .lesson) }

    private static func buildLessons() -> [Category] {
        let db = DB.shared
        return db.lessons.map { l in
            var sections: [DeckSection] = []
            for (i, s) in l.sections.enumerated() {
                let cards = s.ids.compactMap(db.vocabCard)
                let title = s.en == "Vocabulary" ? "Words" : s.en
                sections += split(cards, id: "L\(l.n).s\(i)", title: title, subtitle: s.th)
            }
            let kanji = l.kanji.compactMap(db.kanjiCard)
            if !kanji.isEmpty { sections.append(DeckSection(id: "L\(l.n).k", title: "Kanji", subtitle: l.kanji.joined(separator: " "), cards: kanji)) }
            let grammar = l.grammar.compactMap(db.grammarCard)
            if !grammar.isEmpty { sections.append(DeckSection(id: "L\(l.n).g", title: "Grammar", subtitle: grammar.prefix(4).map(\.prompt).joined(separator: " · "), cards: grammar)) }
            return Category(id: "n5.L\(l.n)", glyph: l.n <= numerals.count ? numerals[l.n - 1] : "\(l.n)",
                            ja: l.ja, en: l.en, caption: "Lesson \(l.n)", sections: sections, kanjiPreview: l.kanji)
        }
    }

    static func vocabByType(_ level: Level) -> [Category] {
        let words = DB.shared.vocab(level)
        let groups: [(String, String, String, (String) -> Bool)] = [
            ("名", "名詞", "Nouns", { ["noun", "pron", "name"].contains($0) }),
            ("動", "動詞", "Verbs", { $0 == "verb" }),
            ("形", "形容詞", "Adjectives", { $0 == "adj" }),
            ("副", "副詞", "Adverbs", { $0 == "adv" }),
            ("数", "助数詞", "Counters", { $0 == "counter" }),
        ]
        var used = Set<String>()
        var out: [Category] = []
        for g in groups {
            let cards = words.filter { g.3($0.vocab!.pos) }
            guard cards.count >= 10 else { continue }
            cards.forEach { used.insert($0.id) }
            out.append(Category(id: "\(level.rawValue).v.\(g.2)", glyph: g.0, ja: g.1, en: g.2, caption: "\(cards.count) words",
                                sections: split(cards, id: "\(level.rawValue).v.\(g.2)", title: g.2, subtitle: "")))
        }
        let rest = words.filter { !used.contains($0.id) }
        if !rest.isEmpty {
            out.append(Category(id: "\(level.rawValue).v.other", glyph: "他", ja: "その他", en: "Particles, suffixes & more", caption: "\(rest.count) words",
                                sections: split(rest, id: "\(level.rawValue).v.other", title: "Other", subtitle: "")))
        }
        return out
    }

    static let kanjiThemes: [(String, String, String)] = [
        ("numbers", "数", "Numbers"), ("timeCalendar", "時", "Time & calendar"), ("peopleBody", "人", "People & body"),
        ("nature", "自然", "Nature & weather"), ("directions", "方向", "Directions"), ("actions", "動作", "Actions"),
        ("places", "場所", "Places & society"), ("adjectives", "形容", "Adjectives & state"), ("concepts", "概念", "Concepts & world"),
    ]

    static func kanjiByTheme(_ level: Level) -> [Category] {
        let all = DB.shared.kanji(level)
        return kanjiThemes.compactMap { key, ja, en in
            let cards = all.filter { $0.kanjiItem!.cat == key }
            guard let first = cards.first else { return nil }
            return Category(id: "\(level.rawValue).k.\(key)", glyph: first.prompt, ja: ja, en: en, caption: "\(cards.count) kanji",
                            sections: split(cards, id: "\(level.rawValue).k.\(key)", title: en, subtitle: ""),
                            kanjiPreview: cards.prefix(12).map(\.prompt))
        }
    }

    static let grammarCats: [(String, String, String, String)] = [
        ("structures", "文", "基本文型", "Sentence structure"), ("particles", "助", "助詞", "Particles"),
        ("verbForms", "動", "動詞の形", "Verb forms"), ("teUses", "て", "て形の使い方", "Uses of the te-form"),
        ("patterns", "型", "文型・表現", "Patterns & expressions"), ("conditionals", "条", "条件", "Conditionals"),
        ("honorifics", "敬", "敬語", "Keigo"),
    ]

    static func grammarByCategory(_ level: Level) -> [Category] {
        let all = DB.shared.grammar(level)
        return grammarCats.compactMap { key, glyph, ja, en in
            let cards = all.filter { $0.grammarItem!.cat == key }
            guard !cards.isEmpty else { return nil }
            return Category(id: "\(level.rawValue).g.\(key)", glyph: glyph, ja: ja, en: en, caption: "\(cards.count) points",
                            sections: split(cards, id: "\(level.rawValue).g.\(key)", title: en, subtitle: ""))
        }
    }

    static func kana() -> [Category] {
        KanaItem.Script.allScripts.map { script in
            let sections = KanaItem.Group.allCases.map { g in
                let cards = KanaData.items(script, g).map(Card.kana)
                return DeckSection(id: "kana.\(script.rawValue).\(g.rawValue)", title: g.en, subtitle: "\(g.ja) · \(cards.count)", cards: cards)
            }
            return Category(id: "kana.\(script.rawValue)", glyph: script == .hira ? "あ" : "ア", ja: script.ja, en: script.en,
                            caption: "\(sections.reduce(0) { $0 + $1.cards.count }) kana", sections: sections)
        }
    }

    /// Splits a long list into ≤ 20-card sections ("Verbs 1", "Verbs 2" …).
    private static func split(_ cards: [Card], id: String, title: String, subtitle: String) -> [DeckSection] {
        guard cards.count > chunk + 5 else { return [DeckSection(id: id, title: title, subtitle: subtitle, cards: cards)] }
        let parts = stride(from: 0, to: cards.count, by: chunk).map { Array(cards[$0..<min($0 + chunk, cards.count)]) }
        return parts.enumerated().map { i, part in
            DeckSection(id: "\(id).\(i + 1)", title: "\(title) \(i + 1)", subtitle: subtitle.isEmpty ? part.prefix(4).map(\.prompt).joined(separator: " · ") : subtitle, cards: part)
        }
    }
}
