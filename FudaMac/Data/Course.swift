import Foundation
import Observation

// The Mac course: 33 lessons (N5 0–14, N4 15–32) in Tone's teaching order,
// plus Tone's lesson dialogues and graded stories. Built by Tools/build_course.py.

struct CourseSection: Codable, Hashable { let en: String; let th: String; let ids: [String] }

struct CourseLesson: Codable, Identifiable, Hashable {
    let n: Int
    let level: Level
    let ja: String
    let th: String
    let en: String
    let grammar: [String]
    let sections: [CourseSection]
    let kanji: [String]
    let dialogues: [String]
    let stories: [String]
    var id: Int { n }

    var isKana: Bool { n == 0 }
    var numeral: String {
        let k = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        if n <= 10 { return k[n] }
        if n < 20 { return "十" + k[n - 10] }
        return k[n / 10] + "十" + (n % 10 == 0 ? "" : k[n % 10])
    }

    var grammarCards: [Card] { grammar.compactMap { DB.shared.grammarCard($0) } }
    var wordCards: [Card] { sections.flatMap(\.ids).compactMap { DB.shared.vocabCard($0) } }
    var kanjiCards: [Card] { kanji.compactMap { DB.shared.kanjiCard($0) } }
    var kanaCards: [Card] { isKana ? DB.shared.kana.map(Card.kana) : [] }
    var allCards: [Card] { kanaCards + wordCards + kanjiCards + grammarCards }
}

struct StorySentence: Codable, Hashable { let ja: String; let kana: String; let th: String; let en: String; let romaji: String }

struct GradedStory: Codable, Identifiable, Hashable {
    let key: String
    let level: Level
    let genre: String
    let title: String
    let jaTitle: String
    let summaryTH: String
    let isLong: Bool
    let paragraphAfter: [Int]
    let sentences: [StorySentence]
    var id: String { key }
    var englishTitle: String { title.components(separatedBy: " — ").last ?? title }
    var thaiTitle: String { title.components(separatedBy: " — ").first ?? title }
    var shelf: String {
        if level == .n4 { return "N4" }
        if genre == "นิทาน" { return "昔話 · Folk tales" }
        return isLong ? "長編 · Longer" : "短編 · Short"
    }
    var minutes: Int { max(1, sentences.count / 6) }
}

struct DialogueLine: Codable, Hashable { let speaker: String; let ja: String; let kana: String; let th: String; let en: String; let romaji: String }

struct LessonDialogue: Codable, Identifiable, Hashable {
    let key: String
    let level: Level
    let title: String
    let jaTitle: String
    let lesson: Int
    let lines: [DialogueLine]
    var id: String { key }
    var englishTitle: String { title.components(separatedBy: " — ").last ?? title }
    /// The speaker the learner plays: the second voice in the dialogue.
    var learnerSpeaker: String {
        let speakers = lines.map(\.speaker).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        if let you = speakers.first(where: { $0 == "タム" || $0 == "あなた" || $0 == "わたし" || $0 == "私" }) { return you }
        return speakers.count > 1 ? speakers[1] : speakers.first ?? ""
    }
}

struct GrammarRegister: Codable, Hashable { let en: String; let th: String }

extension GrammarItem {
    /// Casual vs polite usage notes (from Tone's grammar enrichment).
    var registerEN: String { Course.shared.registers[key]?.en ?? "" }
    var registerTH: String { Course.shared.registers[key]?.th ?? "" }
}

final class Course {
    static let shared = Course()

    let lessons: [CourseLesson]
    let stories: [GradedStory]
    let dialogues: [LessonDialogue]
    let registers: [String: GrammarRegister]
    private let storyByKey: [String: GradedStory]
    private let dialogueByKey: [String: LessonDialogue]

    private init() {
        struct File: Codable { let lessons: [CourseLesson]; let stories: [GradedStory]; let dialogues: [LessonDialogue]; let registers: [String: GrammarRegister] }
        guard let url = Bundle.main.url(forResource: "course", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            assertionFailure("course.json missing or invalid")
            lessons = []; stories = []; dialogues = []; registers = [:]; storyByKey = [:]; dialogueByKey = [:]
            return
        }
        lessons = file.lessons
        stories = file.stories
        dialogues = file.dialogues
        registers = file.registers
        storyByKey = Dictionary(uniqueKeysWithValues: stories.map { ($0.key, $0) })
        dialogueByKey = Dictionary(uniqueKeysWithValues: dialogues.map { ($0.key, $0) })
    }

    func story(_ key: String) -> GradedStory? { storyByKey[key] }
    func dialogue(_ key: String) -> LessonDialogue? { dialogueByKey[key] }
    func lessons(_ level: Level) -> [CourseLesson] { lessons.filter { $0.level == level } }

    /// The lesson a grammar point is taught in.
    func lesson(teaching key: String) -> CourseLesson? { lessons.first { $0.grammar.contains(key) } }
}

// MARK: - Lesson steps

enum LessonStep: String, CaseIterable, Codable, Identifiable {
    // Raw values are stored in progress files: only ever add cases.
    case learn, video, notes, talk, words, kanji, practice, read, test
    var id: String { rawValue }

    /// The steps a lesson shows: textbook lessons get the full book flow
    /// (文型 → ビデオ → 文法 → 会話 → 語彙 → 漢字 → 練習 → 読む → 問題).
    static func steps(for n: Int) -> [LessonStep] {
        if n == 0 { return [.learn, .words, .practice, .test] }
        if Textbook.lesson(n) != nil { return allCases }
        return [.learn, .words, .kanji, .talk, .read, .practice, .test]
    }

    func ja(_ n: Int) -> String {
        let book = n > 0 && Textbook.lesson(n) != nil
        switch self {
        case .learn: return book ? "文型" : "学ぶ"
        case .video: return "動画"; case .notes: return "文法"
        case .words: return "語彙"; case .kanji: return "漢字"; case .talk: return "会話"
        case .read: return "読む"; case .practice: return "練習"; case .test: return book ? "問題" : "試験"
        }
    }
    func en(_ n: Int) -> String {
        let book = n > 0 && Textbook.lesson(n) != nil
        switch self {
        case .learn: return book ? "Patterns" : "Learn"
        case .video: return "Video"; case .notes: return "Grammar"
        case .words: return "Words"; case .kanji: return "Kanji"; case .talk: return "Talk"
        case .read: return "Read"; case .practice: return "Drills"; case .test: return "Test"
        }
    }
    var ja: String { ja(1) }
    var en: String { en(1) }
}

// MARK: - Mac-only progress (lesson steps, tests, stories, essentials)

@Observable
final class CourseProgress {
    private struct Snapshot: Codable {
        var steps: [Int: Set<LessonStep>] = [:]
        var tests: [Int: Int] = [:]
        var stories: Set<String> = []
        var storyBest: [String: Int] = [:]
        var talks: Set<String> = []
        var essentials: Set<Int> = []
        var points: Set<String> = []          // grammar points checked in Learn
    }

    private(set) var steps: [Int: Set<LessonStep>] = [:]
    private(set) var tests: [Int: Int] = [:]
    private(set) var stories: Set<String> = []
    private(set) var storyBest: [String: Int] = [:]
    private(set) var talks: Set<String> = []
    private(set) var essentials: Set<Int> = []
    private(set) var points: Set<String> = []

    @ObservationIgnored private let url: URL

    init(filename: String = "course-progress.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
            steps = s.steps; tests = s.tests; stories = s.stories; storyBest = s.storyBest
            talks = s.talks; essentials = s.essentials; points = s.points
        }
    }

    func isDone(_ lesson: Int, _ step: LessonStep) -> Bool { steps[lesson]?.contains(step) ?? false }
    func doneCount(_ lesson: Int) -> Int { LessonStep.steps(for: lesson).filter { isDone(lesson, $0) }.count }
    func stepCount(_ lesson: Int) -> Int { LessonStep.steps(for: lesson).count }
    func passed(_ lesson: Int) -> Bool { (tests[lesson] ?? 0) >= 70 }

    /// The lesson to continue: the first one that isn't passed.
    var currentLesson: CourseLesson? {
        Course.shared.lessons.first { !passed($0.n) } ?? Course.shared.lessons.last
    }

    func nextStep(_ lesson: Int) -> LessonStep {
        LessonStep.steps(for: lesson).first { !isDone(lesson, $0) } ?? .test
    }

    func complete(_ lesson: Int, _ step: LessonStep) {
        steps[lesson, default: []].insert(step); save()
    }

    func recordTest(_ lesson: Int, score: Int) {
        tests[lesson] = max(tests[lesson] ?? 0, score)
        if score >= 70 { steps[lesson, default: []].insert(.test) }
        save()
    }

    func markPoint(_ key: String) { points.insert(key); save() }
    func markTalk(_ key: String) { talks.insert(key); save() }
    func markEssential(_ id: Int) { essentials.insert(id); save() }
    func recordStory(_ key: String, score: Int) {
        stories.insert(key)
        storyBest[key] = max(storyBest[key] ?? 0, score)
        save()
    }

    func reset() {
        steps = [:]; tests = [:]; stories = []; storyBest = [:]; talks = []; essentials = []; points = []
        save()
    }

    private func save() {
        let snap = Snapshot(steps: steps, tests: tests, stories: stories, storyBest: storyBest, talks: talks, essentials: essentials, points: points)
        if let data = try? JSONEncoder().encode(snap) { try? data.write(to: url, options: .atomic) }
    }
}
