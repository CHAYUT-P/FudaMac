import Foundation

// Exports Tone's course plan, lesson dialogues and stories for Fuda for Mac.
// Build together with Tone's Data/ files + Common/CoursePlan.swift (see README).

struct SOut: Codable { let ja, kana, th, en, romaji: String }
struct StoryOut: Codable { let key, level, genre, title, jaTitle, summaryTH: String; let isLong: Bool; let paragraphAfter: [Int]; let sentences: [SOut] }
struct LineOut: Codable { let speaker, ja, kana, th, en, romaji: String }
struct DialogueOut: Codable { let key, level, title, jaTitle: String; let lesson: Int; let lines: [LineOut] }
struct ChapterOut: Codable { let level, ja, th: String; let keys: [String] }
struct RegOut: Codable { let en, th: String }
struct All: Codable { let chapters: [ChapterOut]; let stories: [StoryOut]; let dialogues: [DialogueOut]; let registers: [String: RegOut] }

func rom(_ ja: String, _ kana: String) -> String { RomajiService.sentenceToRomaji(ja.isEmpty ? kana : ja, kanaSentence: kana) }

var chapters: [ChapterOut] = []
for lvl in JLPTLevel.allCases {
    for c in CoursePlan.chapters(for: lvl) { chapters.append(ChapterOut(level: lvl.rawValue, ja: c.titleJA, th: c.titleTH, keys: c.keys)) }
}
let stories = StoryData.all.map { s in
    StoryOut(key: s.key, level: s.level.rawValue, genre: s.genre, title: s.title, jaTitle: s.jaTitle, summaryTH: s.summaryTH, isLong: s.isLong,
             paragraphAfter: s.paragraphAfter.sorted(), sentences: s.sentences.map { SOut(ja: $0.ja, kana: $0.kana, th: $0.th, en: $0.en, romaji: rom($0.ja, $0.kana)) })
}
let dialogues = ConversationData.dialogues.map { d in
    DialogueOut(key: d.key, level: d.level.rawValue, title: d.title, jaTitle: d.jaTitle, lesson: d.lesson,
                lines: d.lines.map { LineOut(speaker: $0.speaker, ja: $0.ja, kana: $0.kana, th: $0.th, en: $0.en, romaji: rom($0.ja, $0.kana)) })
}
var registers: [String: RegOut] = [:]
for lvl in JLPTLevel.allCases {
    for g in GrammarData.forLevel(lvl) {
        let p = GrammarEnrichment.apply(g)
        if !p.registerEN.isEmpty || !p.registerTH.isEmpty { registers[p.key] = RegOut(en: p.registerEN, th: p.registerTH) }
    }
}
let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
try! enc.encode(All(chapters: chapters, stories: stories, dialogues: dialogues, registers: registers)).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("chapters", chapters.count, "stories", stories.count, "dialogues", dialogues.count)
