import Foundation
import Observation

struct QuizQuestion: Identifiable {
    enum Kind { case meaning, word, listen, reading, kanjiMeaning, kanjiReading, grammarExercise, grammarMeaning, kanaRomaji, romajiKana }

    let id = UUID()
    let card: Card
    let kind: Kind
    let instruction: String
    let prompt: String
    let promptIsJapanese: Bool
    let caption: String
    let audio: String?
    let options: [String]
    let optionsJapanese: Bool
    let answer: Int
    let explanation: String
}

enum QuizMode: String, CaseIterable, Identifiable {
    case mixed, listening
    var id: String { rawValue }
}

enum QuizBuilder {
    static func make(from cards: [Card], count: Int = 10, mode: QuizMode = .mixed) -> [QuizQuestion] {
        var pool = cards.shuffled()
        if mode == .listening { pool = pool.filter { $0.kind == .vocab || $0.kind == .kana } }
        var out: [QuizQuestion] = []
        for c in pool {
            if out.count >= count { break }
            if let q = question(for: c, mode: mode) { out.append(q) }
        }
        return out
    }

    static func question(for card: Card, mode: QuizMode) -> QuizQuestion? {
        switch card.payload {
        case .vocab(let v):
            var kinds: [QuizQuestion.Kind] = mode == .listening ? [.listen] : [.meaning, .word, .listen]
            if v.hasKanji && mode == .mixed { kinds.append(.reading) }
            let kind = kinds.randomElement()!
            let peers = DB.shared.vocab.filter { $0.level == v.level && $0.id != v.id }
            let samePos = peers.filter { $0.pos == v.pos }
            let src = samePos.count >= 6 ? samePos : peers
            switch kind {
            case .meaning:
                return choice(card, kind, "What does this mean?", v.word, true, caption: v.kana, audio: nil,
                              correct: v.th, distractors: src.map(\.th), jp: false, explain: "\(v.word)（\(v.kana)）= \(v.th)")
            case .word:
                return choice(card, kind, "Which word means…", v.th, false, caption: "", audio: nil,
                              correct: v.word, distractors: src.map(\.word), jp: true, explain: "\(v.th) = \(v.word)（\(v.kana)）")
            case .listen:
                return choice(card, kind, "Listen. Which word did you hear?", "", true, caption: "", audio: v.kana,
                              correct: v.word, distractors: src.map(\.word), jp: true, explain: "\(v.kana) → \(v.word) · \(v.th)")
            default:
                let kanjiPeers = src.filter(\.hasKanji)
                return choice(card, .reading, "How is this read?", v.word, true, caption: v.th, audio: nil,
                              correct: v.kana, distractors: similarReadings(v.kana, kanjiPeers.map(\.kana)), jp: true, explain: "\(v.word) is read \(v.kana)")
            }
        case .kanji(let k):
            let peers = DB.shared.kanji.filter { $0.id != k.id }
            if Bool.random() {
                return choice(card, .kanjiMeaning, "What does this kanji mean?", k.char, true, caption: "", audio: nil,
                              correct: k.th, distractors: peers.map(\.th), jp: false, explain: "\(k.char) — \(k.th) · \(k.en)")
            }
            return choice(card, .kanjiReading, "Choose a reading of this kanji", k.char, true, caption: k.th, audio: nil,
                          correct: k.reading, distractors: peers.map(\.reading), jp: true, explain: "音 \(k.on) · 訓 \(k.kun)")
        case .grammar(let g):
            if let ex = g.exercises.filter(\.isChoice).randomElement() {
                let ins = ex.captionEN.isEmpty ? "Choose the best answer" : ex.captionEN
                let explain = [ex.explainTH, ex.explainEN].filter { !$0.isEmpty }.joined(separator: "\n")
                return QuizQuestion(card: card, kind: .grammarExercise, instruction: ins, prompt: ex.prompt, promptIsJapanese: true,
                                    caption: ex.captionTH, audio: nil, options: ex.options, optionsJapanese: true, answer: ex.answer,
                                    explanation: explain.isEmpty ? "\(g.pattern) — \(g.th)" : explain)
            }
            let peers = DB.shared.grammar.filter { $0.key != g.key && $0.level == g.level }
            return choice(card, .grammarMeaning, "What does this pattern mean?", g.pattern, true, caption: g.structure, audio: nil,
                          correct: g.th, distractors: peers.map(\.th), jp: false, explain: "\(g.pattern) — \(g.th) · \(g.en)")
        case .kana(let k):
            let peers = KanaData.all.filter { $0.script == k.script && $0.romaji != k.romaji }
            if mode == .listening || Bool.random() {
                return choice(card, .romajiKana, mode == .listening ? "Listen. Which kana is it?" : "Which kana is “\(k.romaji)”?",
                              mode == .listening ? "" : k.romaji, false, caption: "", audio: mode == .listening ? k.char : nil,
                              correct: k.char, distractors: peers.map(\.char), jp: true, explain: "\(k.char) = \(k.romaji)")
            }
            return choice(card, .kanaRomaji, "How is this read?", k.char, true, caption: "", audio: nil,
                          correct: k.romaji, distractors: peers.map(\.romaji), jp: false, explain: "\(k.char) = \(k.romaji)")
        }
    }

    private static func choice(_ card: Card, _ kind: QuizQuestion.Kind, _ instruction: String, _ prompt: String, _ promptJP: Bool,
                               caption: String, audio: String?, correct: String, distractors: [String], jp: Bool, explain: String) -> QuizQuestion? {
        var seen: Set<String> = [correct]
        var wrong: [String] = []
        for d in distractors.shuffled() where !d.isEmpty && !seen.contains(d) {
            seen.insert(d); wrong.append(d)
            if wrong.count == 3 { break }
        }
        guard wrong.count == 3 else { return nil }
        var options = wrong
        let at = Int.random(in: 0...3)
        options.insert(correct, at: at)
        return QuizQuestion(card: card, kind: kind, instruction: instruction, prompt: prompt, promptIsJapanese: promptJP,
                            caption: caption, audio: audio, options: options, optionsJapanese: jp, answer: at, explanation: explain)
    }

    /// Prefer readings of similar length so the wrong answers are plausible.
    private static func similarReadings(_ r: String, _ pool: [String]) -> [String] {
        let near = pool.filter { abs($0.count - r.count) <= 1 }
        return near.count >= 6 ? near : pool
    }
}

@Observable
final class QuizSession: Identifiable {
    let id = UUID()
    let title: String
    let questions: [QuizQuestion]
    private(set) var index = 0
    private(set) var picked: Int?
    private(set) var results: [Bool] = []
    let started = Date.now

    @ObservationIgnored private let store: ProgressStore

    init(title: String, questions: [QuizQuestion], store: ProgressStore) {
        self.title = title
        self.questions = questions
        self.store = store
    }

    var current: QuizQuestion? { index < questions.count ? questions[index] : nil }
    var isDone: Bool { index >= questions.count }
    var score: Int { results.filter { $0 }.count }
    var missed: [Card] { zip(questions, results).filter { !$0.1 }.map(\.0.card) }

    func pick(_ i: Int) {
        guard picked == nil, let q = current else { return }
        picked = i
        let ok = i == q.answer
        results.append(ok)
        store.recordQuiz(q.card, correct: ok)
        ok ? Haptic.success() : Haptic.warning()
    }

    func next() {
        picked = nil
        index += 1
        if isDone { store.addStudyTime(Int(Date.now.timeIntervalSince(started))) }
    }
}
