import Foundation

// Content is exported from Tone's Swift data (Tools/ExportContent.swift) into
// Resources/content.json — one decode at launch, no giant array literals to
// type-check at build time.

enum Level: String, Codable, CaseIterable, Identifiable {
    case n5, n4
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

struct Vocab: Codable, Identifiable, Hashable {
    let id: String
    let level: Level
    let kanji: String
    let kana: String
    let romaji: String
    let pos: String
    let th: String
    let exJA: String
    let exKana: String
    let exRomaji: String
    let exEN: String
    let exTH: String

    /// Surface form shown on the card (kanji when the word has it).
    var word: String { kanji }
    var hasKanji: Bool { kanji != kana && kanji.unicodeScalars.contains { $0.properties.isIdeographic } }

    var posLabel: String {
        switch pos {
        case "noun", "pron", "name": "NOUN · 名詞"
        case "verb": "VERB · 動詞"
        case "adj": "ADJECTIVE · 形容詞"
        case "adv": "ADVERB · 副詞"
        case "counter": "COUNTER · 助数詞"
        case "particle": "PARTICLE · 助詞"
        case "suffix": "SUFFIX · 接尾辞"
        case "prefix": "PREFIX · 接頭辞"
        case "interj": "INTERJECTION · 感動詞"
        default: pos.uppercased()
        }
    }
}

struct KanjiExample: Codable, Hashable { let w: String; let r: String; let m: String }

struct KanjiItem: Codable, Identifiable, Hashable {
    let id: String          // the glyph
    let level: Level
    let th: String
    let en: String
    let on: String
    let kun: String
    let cat: String
    let reading: String
    let romaji: String
    let strokes: Int
    let examples: [KanjiExample]
    var char: String { id }
}

struct GrammarExample: Codable, Hashable { let ja: String; let kana: String; let th: String; let en: String; let romaji: String }

struct GrammarExercise: Codable, Hashable {
    let prompt: String
    let kana: String
    let captionTH: String
    let captionEN: String
    let explainTH: String
    let explainEN: String
    let options: [String]
    let answer: Int
    let accepted: [String]
    var isChoice: Bool { options.count > 1 && answer < options.count }
}

struct GrammarItem: Codable, Identifiable, Hashable {
    let key: String
    let level: Level
    let pattern: String
    let th: String
    let en: String
    let structure: String
    let explainTH: String
    let explainEN: String
    let cat: String
    let formationTH: String
    let formationEN: String
    let mistakesTH: String
    let mistakesEN: String
    let examples: [GrammarExample]
    let exercises: [GrammarExercise]
    let related: [String]
    var id: String { key }
}

struct LessonSection: Codable, Hashable { let th: String; let en: String; let ids: [String] }

struct Lesson: Codable, Identifiable, Hashable {
    let n: Int
    let ja: String
    let th: String
    let en: String
    let sections: [LessonSection]
    let kanji: [String]
    let grammar: [String]
    var id: Int { n }
}

private struct ContentFile: Codable {
    let vocab: [Vocab]
    let kanji: [KanjiItem]
    let grammar: [GrammarItem]
    let lessons: [Lesson]
}

// MARK: - Content store (read-only, loaded once)

final class DB {
    static let shared = DB()

    let vocab: [Vocab]
    let kanji: [KanjiItem]
    let grammar: [GrammarItem]
    let lessons: [Lesson]
    let kana: [KanaItem]

    private(set) var cardsByID: [String: Card] = [:]

    private init() {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ContentFile.self, from: data) else {
            assertionFailure("content.json missing or invalid")
            vocab = []; kanji = []; grammar = []; lessons = []; kana = KanaData.all
            return
        }
        vocab = file.vocab
        kanji = file.kanji
        grammar = file.grammar
        lessons = file.lessons
        kana = KanaData.all
        for c in vocab.map(Card.vocab) + kanji.map(Card.kanji) + grammar.map(Card.grammar) + kana.map(Card.kana) {
            cardsByID[c.id] = c
        }
    }

    func card(_ id: String) -> Card? { cardsByID[id] }
    func vocabCard(_ vocabID: String) -> Card? { cardsByID["v:" + vocabID] }
    func kanjiCard(_ char: String) -> Card? { cardsByID["k:" + char] }
    func grammarCard(_ key: String) -> Card? { cardsByID["g:" + key] }

    func vocab(_ level: Level) -> [Card] { vocab.filter { $0.level == level }.map(Card.vocab) }
    func kanji(_ level: Level) -> [Card] { kanji.filter { $0.level == level }.map(Card.kanji) }
    func grammar(_ level: Level) -> [Card] { grammar.filter { $0.level == level }.map(Card.grammar) }
    func all(_ level: Level) -> [Card] { vocab(level) + kanji(level) + grammar(level) }

    /// The order new cards are introduced for a level: N5 follows the 14
    /// lessons (words → kanji → grammar each lesson); N4 interleaves
    /// 15 words, 5 kanji, 2 grammar points.
    private var pathCache: [Level: [Card]] = [:]

    func path(_ level: Level) -> [Card] {
        if let p = pathCache[level] { return p }
        let p = buildPath(level)
        pathCache[level] = p
        return p
    }

    private func buildPath(_ level: Level) -> [Card] {
        switch level {
        case .n5:
            var out: [Card] = []
            var seen = Set<String>()
            for l in lessons {
                let ids = l.sections.flatMap(\.ids).map { "v:" + $0 } + l.kanji.map { "k:" + $0 } + l.grammar.map { "g:" + $0 }
                for id in ids where !seen.contains(id) {
                    if let c = cardsByID[id] { out.append(c); seen.insert(id) }
                }
            }
            for c in all(.n5) where !seen.contains(c.id) { out.append(c) }
            return out
        case .n4:
            let v = vocab(.n4), k = kanji(.n4), g = grammar(.n4)
            var out: [Card] = []
            var vi = 0, ki = 0, gi = 0
            while vi < v.count || ki < k.count || gi < g.count {
                out += v[min(vi, v.count)..<min(vi + 15, v.count)]; vi += 15
                out += k[min(ki, k.count)..<min(ki + 5, k.count)]; ki += 5
                out += g[min(gi, g.count)..<min(gi + 2, g.count)]; gi += 2
            }
            return out
        }
    }

    func search(_ q: String, level: Level?) -> [Card] {
        let q = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let pool = cardsByID.values.filter { level == nil || $0.level == level }
        return pool.filter { $0.searchText.contains(q) }
            .sorted { a, b in
                let ae = a.exactMatch(q), be = b.exactMatch(q)
                if ae != be { return ae }
                return a.prompt.count < b.prompt.count
            }
            .prefix(80).map { $0 }
    }
}
