import Foundation
import CoreGraphics

// Textbook lessons: one JSON per lesson (Resources/textbook-LNN.json), written
// to the format in Tools/textbook/SCHEMA.md. Every field the app reads is
// optional-tolerant so a thin lesson still renders.

struct TBText: Codable, Hashable {
    var ja: String
    var kana: String
    var th: String?
    var en: String?
    var romaji: String { Furigana.romaji(ja, kana) }
}

struct TBPattern: Codable, Hashable { var ja: String; var kana: String; var th: String; var noteTH: String? }
struct TBExample: Codable, Hashable { var q: TBText; var a: TBText }
struct TBLine: Codable, Hashable { var speaker: String; var ja: String; var kana: String; var th: String }
struct TBConversation: Codable, Hashable { var titleJA: String; var titleTH: String; var sceneTH: String?; var lines: [TBLine] }

struct TBBlock: Codable, Hashable {
    var t: String
    var th: String?
    var ja: String?
    var kana: String?
    var rows: [[String]]?
    var left: TBText?
    var right: TBText?
}

struct TBGrammar: Codable, Hashable, Identifiable {
    var key: String?
    var keys: [String]?
    var titleJA: String
    var titleTH: String
    var blocks: [TBBlock]
    var id: String { titleJA + titleTH }
    var allKeys: [String] { [key].compactMap { $0 } + (keys ?? []) }
}

struct TBTok: Codable, Hashable { var id: String; var text: String; var k: String?; var s: String?; var r: String?; var c: String? }
struct TBTimeline: Codable, Hashable {
    var bar: [Double]?; var solid: Bool?; var event: Double?; var eventLabel: String?; var ticks: [Double]?; var caption: String?
}
struct TBBeat: Codable, Hashable { var th: String; var say: String?; var kicker: String?; var rows: [[TBTok]]?; var timeline: TBTimeline? }
struct TBChapter: Codable, Hashable { var chapterTH: String; var beats: [TBBeat] }

struct TBDrillARow: Codable, Hashable { var ja: String; var kana: String; var th: String; var slots: [String]? }
struct TBDrillA: Codable, Hashable { var titleTH: String; var frame: String; var rows: [TBDrillARow] }
struct TBDrillBItem: Codable, Hashable { var prompt: TBText; var answer: TBText; var accept: [String]? }
struct TBDrillB: Codable, Hashable { var instructionTH: String; var items: [TBDrillBItem] }
struct TBDrillC: Codable, Hashable { var situationTH: String; var lines: [TBLine]; var choices: [[TBText]] }

struct TBQuiz: Codable, Hashable {
    var type: String
    var questionTH: String
    var ja: String?
    var kana: String?
    var options: [String]?
    var answer: Int?
    var tiles: [String]?
    var explainTH: String?
}

struct TextbookLesson: Codable, Hashable {
    var n: Int
    var titleJA: String
    var titleTH: String
    var goalsTH: [String]
    var patterns: [TBPattern]
    var examples: [TBExample]
    var conversation: TBConversation
    var grammar: [TBGrammar]
    var video: [TBChapter]
    var drillA: [TBDrillA]
    var drillB: [TBDrillB]
    var drillC: [TBDrillC]
    var quiz: [TBQuiz]

    var beatCount: Int { video.reduce(0) { $0 + $1.beats.count } }
}

enum Textbook {
    nonisolated(unsafe) private static var cache: [Int: TextbookLesson?] = [:]

    static func lesson(_ n: Int) -> TextbookLesson? {
        if let hit = cache[n] { return hit }
        var out: TextbookLesson?
        if let url = Bundle.main.url(forResource: String(format: "textbook-L%02d", n), withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            do { out = try JSONDecoder().decode(TextbookLesson.self, from: data) }
            catch { print("textbook-L\(n): \(error)") }
        }
        cache[n] = out
        return out
    }

    struct Hit: Identifiable, Hashable { let lesson: Int; let section: Int; let titleJA: String; let titleTH: String; var id: String { "\(lesson)-\(section)" } }

    /// Grammar sections whose title, Thai title or grammar pattern matches the query.
    static func search(_ query: String) -> [Hit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let hira = KanaData.toHiragana(q)
        var out: [Hit] = []
        for n in 1...32 {
            guard let tb = lesson(n) else { continue }
            for (i, g) in tb.grammar.enumerated() {
                let patterns = g.allKeys.compactMap { DB.shared.grammarCard($0)?.prompt }
                let hay = ([g.titleJA, g.titleTH] + patterns).joined(separator: " ").lowercased()
                if hay.contains(q) || KanaData.toHiragana(hay).contains(hira) {
                    out.append(Hit(lesson: n, section: i, titleJA: g.titleJA, titleTH: g.titleTH))
                }
            }
        }
        return out
    }
}

// MARK: - Conversions to the existing players

extension TextbookLesson {
    /// The video as lesson-player beats, plus where each chapter starts.
    var playerBeats: (beats: [LessonBeat], chapters: [LessonChapter]) {
        var beats: [LessonBeat] = []
        var chapters: [LessonChapter] = []
        for ch in video {
            chapters.append(LessonChapter(title: ch.chapterTH, start: beats.count))
            for b in ch.beats {
                var rows: [LessonRow] = []
                if let t = b.timeline {
                    var lt = LessonTimeline()
                    if let bar = t.bar, bar.count == 2 { lt.bar = CGFloat(min(bar[0], bar[1]))...CGFloat(max(bar[0], bar[1])) }
                    lt.solid = t.solid ?? false
                    lt.event = t.event.map { CGFloat($0) }
                    lt.eventLabel = t.eventLabel ?? ""
                    lt.ticks = (t.ticks ?? []).map { CGFloat($0) }
                    lt.caption = t.caption ?? ""
                    rows.append(tl(lt))
                }
                for (i, r) in (b.rows ?? []).enumerated() {
                    rows.append(LessonRow(id: "r\(i)", toks: r.map(\.lessonTok)))
                }
                beats.append(LessonBeat(kicker: b.kicker ?? ch.chapterTH, rows: rows, en: "", th: b.th, say: b.say))
            }
        }
        return (beats, chapters)
    }

    /// The main conversation in the dialogue player's format.
    var dialogue: LessonDialogue {
        LessonDialogue(key: "tb-\(n)", level: n <= 14 ? .n5 : .n4, title: conversation.titleTH, jaTitle: conversation.titleJA, lesson: n,
                       lines: conversation.lines.map { DialogueLine(speaker: $0.speaker, ja: $0.ja, kana: $0.kana, th: $0.th, en: "", romaji: Furigana.romaji($0.ja, $0.kana)) })
    }
}

extension TBTok {
    var lessonTok: LessonTok {
        let kind: LessonTok.Kind = switch k ?? "plain" {
        case "key": .key; case "ink": .ink; case "ghost": .ghost; case "op": .op
        case "strike": .strike; case "label": .label; case "note": .note; default: .plain
        }
        let size: LessonTok.Size = switch s ?? "big" {
        case "huge": .huge; case "mid": .mid; case "small": .small; default: .big
        }
        return LessonTok(id: id, text: text, kind: kind, size: size, ruby: r, caption: c)
    }
}

extension TBDrillC {
    /// Fill {0}, {1} … with option `variant` of every choices list.
    func fill(_ s: String, variant: Int, key: KeyPath<TBText, String>) -> String {
        var out = s
        for (i, list) in choices.enumerated() where list.indices.contains(variant) {
            out = out.replacingOccurrences(of: "{\(i)}", with: list[variant][keyPath: key])
        }
        return out
    }
    func fillTH(_ s: String, variant: Int) -> String {
        var out = s
        for (i, list) in choices.enumerated() where list.indices.contains(variant) {
            out = out.replacingOccurrences(of: "{\(i)}", with: list[variant].th ?? list[variant].ja)
        }
        return out
    }
    var variants: Int { choices.map(\.count).min() ?? 0 }
}

/// Answer checking for typed drills: ignore spaces and punctuation, accept kana
/// or kanji, hiragana or katakana.
enum AnswerCheck {
    static func norm(_ s: String) -> String {
        let drop = Set(" 　。、．，.,!?！？「」")
        return KanaData.toHiragana(String(s.filter { !drop.contains($0) }))
    }
    static func matches(_ typed: String, _ answers: [String]) -> Bool {
        let t = norm(typed)
        return !t.isEmpty && answers.contains { norm($0) == t }
    }
    /// The typed text read aloud (kanji → kana), so a kanji/kana mix like 高くありません matches the answer's kana.
    static func reading(_ typed: String) -> String {
        norm(AutoReading.tokens(typed).map { $0.kana ?? $0.surface }.joined())
    }
}
