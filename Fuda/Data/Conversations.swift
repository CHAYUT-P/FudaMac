import Foundation

// Real-life conversation scenes, authored in Tools/conversations.txt and
// built into Resources/conversations.json by Tools/build_conversations.py.

struct TalkAlt: Codable, Hashable {
    let ja: String
    let kana: String
    let th: String
    let en: String
    var romaji: String = ""

    enum CodingKeys: String, CodingKey { case ja, kana, th, en, romaji }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        ja = try c.decode(String.self, forKey: .ja)
        kana = try c.decode(String.self, forKey: .kana)
        th = try c.decode(String.self, forKey: .th)
        en = try c.decode(String.self, forKey: .en)
        romaji = try c.decodeIfPresent(String.self, forKey: .romaji) ?? Romaji.from(kana)
    }
}

struct TalkLine: Codable, Hashable {
    let kind: String            // "line" | "section"
    let ja: String
    let th: String
    let en: String
    var speaker: String = ""
    var you: Bool = false
    var key: Bool = false
    var kana: String = ""
    var noteEN: String = ""
    var noteTH: String = ""
    var alts: [TalkAlt] = []
    var romaji: String = ""

    var isSection: Bool { kind == "section" }

    enum CodingKeys: String, CodingKey { case kind, ja, th, en, speaker, you, key, kana, noteEN, noteTH, alts, romaji }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        ja = try c.decode(String.self, forKey: .ja)
        th = try c.decode(String.self, forKey: .th)
        en = try c.decode(String.self, forKey: .en)
        speaker = try c.decodeIfPresent(String.self, forKey: .speaker) ?? ""
        you = try c.decodeIfPresent(Bool.self, forKey: .you) ?? false
        key = try c.decodeIfPresent(Bool.self, forKey: .key) ?? false
        kana = try c.decodeIfPresent(String.self, forKey: .kana) ?? ""
        noteEN = try c.decodeIfPresent(String.self, forKey: .noteEN) ?? ""
        noteTH = try c.decodeIfPresent(String.self, forKey: .noteTH) ?? ""
        alts = try c.decodeIfPresent([TalkAlt].self, forKey: .alts) ?? []
        romaji = try c.decodeIfPresent(String.self, forKey: .romaji) ?? Romaji.from(kana)
    }
}

struct TalkRole: Codable, Hashable { let en: String; let th: String }

enum TalkPlace: String, Codable, CaseIterable, Identifiable {
    case shop, food, transport, daily, health, people
    var id: String { rawValue }
    var ja: String {
        switch self {
        case .shop: "買い物"; case .food: "食事"; case .transport: "移動"
        case .daily: "生活"; case .health: "健康・緊急"; case .people: "人"
        }
    }
    var en: String {
        switch self {
        case .shop: "Shopping"; case .food: "Eating out"; case .transport: "Getting around"
        case .daily: "Daily life"; case .health: "Health & help"; case .people: "People"
        }
    }
}

struct TalkScene: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let en: String
    let th: String
    let glyph: String
    let level: Level
    let place: TalkPlace
    let aboutEN: String
    let aboutTH: String
    let roles: [String: TalkRole]
    let lines: [TalkLine]

    static func == (a: TalkScene, b: TalkScene) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var spoken: [TalkLine] { lines.filter { !$0.isSection } }
    var keyPhrases: [TalkLine] { spoken.filter { $0.key && !$0.you } }
    var yourLines: Int { spoken.filter(\.you).count }

    func roleName(_ speaker: String, english: Bool) -> String {
        guard let r = roles[speaker] else { return speaker }
        return "\(speaker) · \(english ? r.en : r.th)"
    }
}

enum Talk {
    static let scenes: [TalkScene] = {
        struct File: Codable { let scenes: [TalkScene] }
        guard let url = Bundle.main.url(forResource: "conversations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            assertionFailure("conversations.json missing or invalid")
            return []
        }
        return file.scenes
    }()
}

// MARK: - Role-play turns

/// One "your turn": what they said, the line you should answer, and choices.
struct TalkTurn: Identifiable {
    let id: Int
    let prompts: [TalkLine]
    let answer: TalkLine?
    let options: [String]
    let correct: Int
}

enum RolePlay {
    static func turns(for scene: TalkScene) -> [TalkTurn] {
        let spoken = scene.spoken
        let yours = spoken.filter(\.you).map(\.ja)
        var turns: [TalkTurn] = []
        var pending: [TalkLine] = []
        for line in spoken {
            guard line.you else { pending.append(line); continue }
            var wrong = Array(Set(yours.filter { $0 != line.ja && !line.alts.map(\.ja).contains($0) })).shuffled()
            wrong = Array(wrong.prefix(2))
            var options = wrong
            let at = Int.random(in: 0...wrong.count)
            options.insert(line.ja, at: at)
            turns.append(TalkTurn(id: turns.count, prompts: pending, answer: line, options: options, correct: at))
            pending = []
        }
        if !pending.isEmpty {
            turns.append(TalkTurn(id: turns.count, prompts: pending, answer: nil, options: [], correct: 0))
        }
        return turns
    }
}
