import Foundation
import Observation

// JLPT exams: real past tests (Resources/Exams/exams-real.json, built from Tone by
// Tools/exams/build_exams.py, with the official listening tracks and pictures) and
// Fuda's original practice tests (exams-original-*.json). Format: Tools/exams/SCHEMA.md.

struct ExamQ: Codable, Identifiable, Hashable {
    let id: String
    let no: Int
    let type: String                 // vocab · grammar · reading · listening
    var img: String = ""
    let prompt: String
    let options: [String]
    let answer: Int
    var explainTH: String = ""
    var explainEN: String = ""
    var optionNotes: [String] = []
    var grammarKeys: [String] = []
    var script: [String] = []        // listening: what is said
    var spokenOptions: [String] = [] // listening: choices that are only spoken
    var questionLine: String = ""

    var isListening: Bool { type == "listening" }
}

struct ExamBlock: Codable, Identifiable, Hashable {
    let id: String
    let nameJA: String
    var nameTH: String = ""
    var nameEN: String = ""
    var instructionJA: String = ""
    var passageJA: String = ""
    var passageKana: String = ""
    var audio: String = ""            // official listening track (Resources/Exams/Audio/NAME.m4a)
    let questions: [ExamQ]
}

struct ExamPart: Codable, Identifiable, Hashable {
    let id: String
    let section: String               // vocab · grammar · listening
    let titleJA: String
    var titleTH: String = ""
    let minutes: Int
    let blocks: [ExamBlock]

    var questions: [ExamQ] { blocks.flatMap(\.questions) }
    var isListening: Bool { section == "listening" }
    var sectionJA: String {
        switch section {
        case "vocab": "言語知識（文字・語彙）"
        case "grammar": "言語知識（文法）・読解"
        default: "聴解"
        }
    }
    var sectionTH: String {
        switch section {
        case "vocab": "คำศัพท์และตัวอักษร"
        case "grammar": "ไวยากรณ์และการอ่าน"
        default: "การฟัง"
        }
    }
}

struct ExamSet: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case full, partial, original }
    let id: String
    let level: Level
    let kind: Kind
    var format: String = "new"
    var order: Int = 0
    let label: String
    var labelEN: String = ""
    var titleJA: String = ""
    var noteTH: String = ""
    var source: String = ""
    var missing: [String] = []
    let parts: [ExamPart]

    var questions: [ExamQ] { parts.flatMap(\.questions) }
    var minutes: Int { parts.reduce(0) { $0 + $1.minutes } }
    var hasListening: Bool { parts.contains(where: \.isListening) }
    var hasRealAudio: Bool { parts.contains { $0.blocks.contains { !$0.audio.isEmpty } } }
    var kindTH: String {
        switch kind {
        case .full: "ข้อสอบจริง · ครบทุกพาร์ต"
        case .partial: missing.contains("listening") ? "ข้อสอบจริง · ไม่มีพาร์ตฟัง" : "ข้อสอบจริง · ตัวอย่างสั้น"
        case .original: "แต่งขึ้นตามรูปแบบจริง"
        }
    }
}

// MARK: - Library

final class ExamLibrary {
    static let shared = ExamLibrary()
    let sets: [ExamSet]
    private let blockOf: [String: ExamBlock]     // question id → its block (passage, audio, instruction)
    private let setOf: [String: ExamSet]         // question id → its set

    private init() {
        struct File: Codable { let sets: [ExamSet] }
        var all: [ExamSet] = []
        let urls = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("exams-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in urls {
            do { all += try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).sets }
            catch { print("exams: \(url.lastPathComponent): \(error)") }
        }
        sets = all
        var b: [String: ExamBlock] = [:], s: [String: ExamSet] = [:]
        for set in all { for p in set.parts { for blk in p.blocks { for q in blk.questions { b[q.id] = blk; s[q.id] = set } } } }
        blockOf = b; setOf = s
    }

    func sets(_ level: Level) -> [ExamSet] { sets.filter { $0.level == level }.sorted { $0.order < $1.order } }
    func set(_ id: String) -> ExamSet? { sets.first { $0.id == id } }
    func block(of q: ExamQ) -> ExamBlock? { blockOf[q.id] }
    func set(of q: ExamQ) -> ExamSet? { setOf[q.id] }
    func question(_ id: String) -> ExamQ? { setOf[id]?.questions.first { $0.id == id } }

    static func imageURL(_ name: String) -> URL? { name.isEmpty ? nil : Bundle.main.url(forResource: name, withExtension: "png") }
    static func audioURL(_ name: String) -> URL? { name.isEmpty ? nil : Bundle.main.url(forResource: name, withExtension: "m4a") }
}

// MARK: - Official rules and scoring

enum ExamRules {
    struct Mondai { let name: String; let th: String; let count: Int }
    struct Section { let key: String; let ja: String; let th: String; let minutes: Int; let mondai: [Mondai] }

    /// The test since 2020 (official JLPT format for N5 / N4).
    static func sections(_ level: Level) -> [Section] {
        level == .n5 ? [
            Section(key: "vocab", ja: "言語知識（文字・語彙）", th: "คำศัพท์และตัวอักษร", minutes: 20, mondai: [
                Mondai(name: "漢字読み", th: "อ่านคันจิเป็นฮิรางานะ", count: 7), Mondai(name: "表記", th: "เขียนคำเป็นคันจิ/คาตาคานะ", count: 5),
                Mondai(name: "文脈規定", th: "เติมคำให้เข้ากับประโยค", count: 6), Mondai(name: "言い換え類義", th: "เลือกประโยคที่ความหมายเหมือนกัน", count: 3)]),
            Section(key: "grammar", ja: "言語知識（文法）・読解", th: "ไวยากรณ์และการอ่าน", minutes: 40, mondai: [
                Mondai(name: "文の文法１", th: "เลือกไวยากรณ์ที่เข้ากับประโยค", count: 9), Mondai(name: "文の文法２", th: "เรียงคำ ★ ให้ถูก", count: 4),
                Mondai(name: "文章の文法", th: "เติมคำในบทความ", count: 4), Mondai(name: "内容理解（短文）", th: "อ่านเรื่องสั้น", count: 2),
                Mondai(name: "内容理解（中文）", th: "อ่านเรื่องยาวปานกลาง", count: 2), Mondai(name: "情報検索", th: "หาข้อมูลจากประกาศ/ตาราง", count: 1)]),
            Section(key: "listening", ja: "聴解", th: "การฟัง", minutes: 30, mondai: [
                Mondai(name: "課題理解", th: "ฟังแล้วตอบว่าต้องทำอะไร", count: 7), Mondai(name: "ポイント理解", th: "ฟังจับใจความสำคัญ", count: 6),
                Mondai(name: "発話表現", th: "ดูรูปแล้วเลือกคำพูดที่เหมาะสม", count: 5), Mondai(name: "即時応答", th: "ฟังแล้วเลือกคำตอบทันที", count: 6)])
        ] : [
            Section(key: "vocab", ja: "言語知識（文字・語彙）", th: "คำศัพท์และตัวอักษร", minutes: 25, mondai: [
                Mondai(name: "漢字読み", th: "อ่านคันจิเป็นฮิรางานะ", count: 7), Mondai(name: "表記", th: "เขียนคำเป็นคันจิ", count: 5),
                Mondai(name: "文脈規定", th: "เติมคำให้เข้ากับประโยค", count: 8), Mondai(name: "言い換え類義", th: "เลือกประโยคที่ความหมายเหมือนกัน", count: 4),
                Mondai(name: "用法", th: "เลือกประโยคที่ใช้คำนั้นถูกต้อง", count: 4)]),
            Section(key: "grammar", ja: "言語知識（文法）・読解", th: "ไวยากรณ์และการอ่าน", minutes: 55, mondai: [
                Mondai(name: "文の文法１", th: "เลือกไวยากรณ์ที่เข้ากับประโยค", count: 13), Mondai(name: "文の文法２", th: "เรียงคำ ★ ให้ถูก", count: 4),
                Mondai(name: "文章の文法", th: "เติมคำในบทความ", count: 4), Mondai(name: "内容理解（短文）", th: "อ่านเรื่องสั้น", count: 3),
                Mondai(name: "内容理解（中文）", th: "อ่านเรื่องยาวปานกลาง", count: 3), Mondai(name: "情報検索", th: "หาข้อมูลจากประกาศ/ตาราง", count: 2)]),
            Section(key: "listening", ja: "聴解", th: "การฟัง", minutes: 35, mondai: [
                Mondai(name: "課題理解", th: "ฟังแล้วตอบว่าต้องทำอะไร", count: 8), Mondai(name: "ポイント理解", th: "ฟังจับใจความสำคัญ", count: 7),
                Mondai(name: "発話表現", th: "ดูรูปแล้วเลือกคำพูดที่เหมาะสม", count: 5), Mondai(name: "即時応答", th: "ฟังแล้วเลือกคำตอบทันที", count: 8)])
        ]
    }

    static func passMark(_ level: Level) -> Int { level == .n5 ? 80 : 90 }   // of 180
    static let sectionMinimums = (knowledge: 38, listening: 19)             // of 120 / 60

    /// Estimated scaled scores. JLPT equates real scores across sittings; a straight
    /// share of correct answers is the usual estimate.
    struct Score: Codable, Hashable {
        var knowledge: Int        // 言語知識（文字・語彙・文法）・読解, 0–120
        var listening: Int?       // 聴解, 0–60 (nil when the set has no listening)
        var total: Int { knowledge + (listening ?? 0) }
        func passed(_ level: Level) -> Bool? {
            guard let l = listening else { return nil }
            return total >= ExamRules.passMark(level) && knowledge >= ExamRules.sectionMinimums.knowledge && l >= ExamRules.sectionMinimums.listening
        }
    }

    static func score(_ set: ExamSet, answers: [String: Int]) -> Score {
        func share(_ qs: [ExamQ]) -> Double {
            qs.isEmpty ? 0 : Double(qs.filter { answers[$0.id] == $0.answer }.count) / Double(qs.count)
        }
        let knowledge = set.parts.filter { !$0.isListening }.flatMap(\.questions)
        let listening = set.parts.filter(\.isListening).flatMap(\.questions)
        return Score(knowledge: Int((share(knowledge) * 120).rounded()),
                     listening: listening.isEmpty ? nil : Int((share(listening) * 60).rounded()))
    }
}

// MARK: - Results (saved safely: a backup copy, and never overwritten after a failed read)

struct ExamAttempt: Codable, Identifiable, Hashable {
    var id = UUID()
    let setID: String
    let date: Date
    let answers: [String: Int]
    let score: ExamRules.Score
    let correct: Int
    let total: Int
}

@Observable
final class ExamStore {
    private struct Snapshot: Codable {
        var attempts: [ExamAttempt] = []
        var misses: [String: Int] = [:]      // question id → times answered wrong (random practice + exams)
        var rights: [String: Int] = [:]
    }

    private(set) var attempts: [ExamAttempt] = []
    private(set) var misses: [String: Int] = [:]
    private(set) var rights: [String: Int] = [:]
    @ObservationIgnored private let url: URL
    @ObservationIgnored private var readOK = true

    init(filename: String = "exam-results.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        if let data = try? Data(contentsOf: url), let s = try? dec.decode(Snapshot.self, from: data) {
            attempts = s.attempts; misses = s.misses; rights = s.rights
        } else if let data = try? Data(contentsOf: url.appendingPathExtension("bak")), let s = try? dec.decode(Snapshot.self, from: data) {
            attempts = s.attempts; misses = s.misses; rights = s.rights      // fall back to the backup
        } else {
            readOK = false   // keep the unreadable file as it is; don't overwrite it
        }
    }

    func best(_ setID: String) -> ExamAttempt? { attempts.filter { $0.setID == setID }.max { $0.score.total < $1.score.total } }
    func last(_ setID: String) -> ExamAttempt? { attempts.filter { $0.setID == setID }.max { $0.date < $1.date } }

    func record(_ a: ExamAttempt, questions: [ExamQ]) {
        attempts.append(a)
        for q in questions { mark(q, right: a.answers[q.id] == q.answer, save: false) }
        save()
    }

    func mark(_ q: ExamQ, right: Bool, save doSave: Bool = true) {
        if right { rights[q.id, default: 0] += 1 } else { misses[q.id, default: 0] += 1 }
        if doSave { save() }
    }

    private func save() {
        guard readOK else { return }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        guard let data = try? enc.encode(Snapshot(attempts: attempts, misses: misses, rights: rights)) else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let bak = url.appendingPathExtension("bak")
            try? fm.removeItem(at: bak)
            try? fm.copyItem(at: url, to: bak)
        }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Text helpers

enum ExamText {
    /// Speaker of a listening line ("Ｆ：…", "男：…") and the text without the label.
    static func speaker(_ line: String) -> (voice: Speech.Voice, text: String) {
        let labels: [(String, Speech.Voice)] = [("Ｆ：", .partner), ("F：", .partner), ("F:", .partner), ("女：", .partner), ("女の人：", .partner),
                                                 ("Ｍ：", .main), ("M：", .main), ("M:", .main), ("男：", .main), ("男の人：", .main)]
        for (l, v) in labels where line.hasPrefix(l) { return (v, String(line.dropFirst(l.count))) }
        return (.main, line)
    }

    /// What the app reads aloud for a listening question: the script, then the spoken choices.
    static func spokenLines(_ q: ExamQ) -> [(Speech.Voice, String)] {
        var lines = q.script.map { l -> (Speech.Voice, String) in let s = speaker(l); return (s.voice, s.text) }
        // 即時応答 scripts sometimes hold the choices on one line ("１．…　２．…"): read them from spokenOptions instead.
        if !q.spokenOptions.isEmpty {
            lines.removeAll { $0.1.contains("１．") || $0.1.contains("1.") }
            let nums = ["いち", "に", "さん", "よん"]
            for (i, o) in q.spokenOptions.enumerated() { lines.append((.main, "\(nums[min(i, 3)])。\(o)")) }
        }
        return lines
    }

    static let typeTH: [String: String] = ["vocab": "文字・語彙", "grammar": "文法", "reading": "読解", "listening": "聴解"]
}
