import Foundation

enum Grade: Int, Codable, CaseIterable {
    case again, hard, good, easy
    var en: String {
        switch self { case .again: "Again"; case .hard: "Hard"; case .good: "Good"; case .easy: "Easy" }
    }
    var ja: String {
        switch self { case .again: "もう一度"; case .hard: "難しい"; case .good: "良い"; case .easy: "簡単" }
    }
}

enum Mastery: Int, Comparable, CaseIterable {
    case new, learning, young, mature
    static func < (a: Mastery, b: Mastery) -> Bool { a.rawValue < b.rawValue }
    var en: String {
        switch self { case .new: "New"; case .learning: "Learning"; case .young: "Young"; case .mature: "Mature" }
    }
    /// Ink density used for screentone fills — the app's "ink = memory" rule.
    var density: CGFloat {
        switch self { case .new: 0; case .learning: 0.35; case .young: 0.7; case .mature: 1 }
    }
}

struct CardState: Codable, Hashable {
    enum Phase: String, Codable { case learning, review, relearning }
    var phase: Phase = .learning
    var step = 0
    var interval: Double = 0     // days (review phase)
    var ease: Double = 2.5
    var reps = 0
    var lapses = 0
    var due: Date
    var last: Date
    var firstSeen: Date

    var mastery: Mastery {
        switch phase {
        case .learning, .relearning: .learning
        case .review: interval >= 21 ? .mature : .young
        }
    }
}

/// SM-2 style scheduler with Anki-like learning steps.
enum Scheduler {
    static let learningSteps: [TimeInterval] = [60]          // Again → 1 min; Good graduates
    static let relearnDelay: TimeInterval = 600
    static let minEase = 1.3
    static let day: TimeInterval = 86_400

    static func next(_ state: CardState?, _ grade: Grade, now: Date = .now) -> CardState {
        var s = state ?? CardState(due: now, last: now, firstSeen: now)
        s.reps += 1
        s.last = now
        switch s.phase {
        case .learning:
            switch grade {
            case .again: s.step = 0; s.due = now + learningSteps[0]
            case .hard: s.due = now + (s.step == 0 ? 360 : learningSteps[min(s.step, learningSteps.count - 1)])
            case .good:
                if s.step + 1 < learningSteps.count {
                    s.step += 1; s.due = now + learningSteps[s.step]
                } else { graduate(&s, days: 1, now: now) }
            case .easy: graduate(&s, days: 4, now: now)
            }
        case .relearning:
            switch grade {
            case .again, .hard: s.due = now + relearnDelay
            case .good, .easy: s.phase = .review; s.due = dueDate(now, days: s.interval)
            }
        case .review:
            switch grade {
            case .again:
                s.lapses += 1
                s.ease = max(minEase, s.ease - 0.2)
                s.interval = max(1, (s.interval * 0.5).rounded())
                s.phase = .relearning
                s.due = now + relearnDelay
            case .hard:
                s.ease = max(minEase, s.ease - 0.15)
                s.interval = cap(max(s.interval + 1, s.interval * 1.2))
                s.due = dueDate(now, days: s.interval)
            case .good:
                s.interval = cap(max(s.interval + 1, s.interval * s.ease))
                s.due = dueDate(now, days: s.interval)
            case .easy:
                s.interval = cap(max(s.interval + 2, s.interval * s.ease * 1.3))
                s.ease += 0.15
                s.due = dueDate(now, days: s.interval)
            }
        }
        return s
    }

    private static func graduate(_ s: inout CardState, days: Double, now: Date) {
        s.phase = .review; s.step = 0; s.interval = days; s.due = dueDate(now, days: days)
    }

    private static func cap(_ d: Double) -> Double { min(3650, d.rounded()) }

    /// Reviews land at 4 am local on the due day, so "due today" is stable.
    private static func dueDate(_ now: Date, days: Double) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let target = cal.date(byAdding: .day, value: Int(days.rounded()), to: start) ?? now + days * day
        return cal.date(byAdding: .hour, value: 4, to: target) ?? target
    }

    /// Short label for the grade buttons — "1 min", "3 days".
    static func label(_ state: CardState?, _ grade: Grade, now: Date = .now) -> String {
        let next = Scheduler.next(state, grade, now: now)
        let secs = next.due.timeIntervalSince(now)
        if secs < 3600 { return "\(max(1, Int((secs / 60).rounded()))) min" }
        if secs < day * 0.9 { return "\(Int((secs / 3600).rounded())) h" }
        let d = Int(next.interval.rounded())
        if d < 31 { return d == 1 ? "1 day" : "\(d) days" }
        if d < 365 { return "\(Int((Double(d) / 30).rounded())) mo" }
        return String(format: "%.1f yr", Double(d) / 365)
    }
}
