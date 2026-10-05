import Foundation
import Observation

enum StudyDirection: String, CaseIterable, Identifiable {
    case recognition, production, listening
    var id: String { rawValue }
    var ja: String {
        switch self { case .recognition: "表→裏"; case .production: "裏→表"; case .listening: "聴" }
    }
    var en: String {
        switch self { case .recognition: "JP → meaning"; case .production: "Meaning → JP"; case .listening: "Listen" }
    }
}

// MARK: - Building a session

enum SessionBuilder {
    /// Today: everything due (any level), then new cards along the level's path.
    static func today(_ store: ProgressStore) -> [Card] {
        let size = store.settings.sessionSize
        let due = Array(store.dueCards().prefix(size))
        let room = min(store.newRemainingToday, size - due.count)
        guard room > 0 else { return due }
        let fresh = DB.shared.path(store.settings.level).lazy.filter { store.state($0.id) == nil }.prefix(room)
        return interleave(due, Array(fresh))
    }

    /// A deck/section: its due cards, then its new cards. Nothing to do →
    /// a review pass over the cards least recently seen.
    static func deck(_ cards: [Card], _ store: ProgressStore) -> [Card] {
        let size = store.settings.sessionSize
        let now = Date.now
        let due = cards.filter { store.isDue($0.id, now: now) }.prefix(size)
        let fresh = cards.filter { store.state($0.id) == nil }.prefix(size - due.count)
        let out = interleave(Array(due), Array(fresh))
        if !out.isEmpty { return out }
        return cram(cards, store)
    }

    static func cram(_ cards: [Card], _ store: ProgressStore) -> [Card] {
        Array(cards.sorted { (store.state($0.id)?.last ?? .distantPast) < (store.state($1.id)?.last ?? .distantPast) }
            .prefix(store.settings.sessionSize)).shuffled()
    }

    static func newCount(_ cards: [Card], _ store: ProgressStore) -> (due: Int, new: Int) {
        let size = store.settings.sessionSize
        let due = min(size, cards.filter { store.isDue($0.id) }.count)
        let new = min(size - due, cards.filter { store.state($0.id) == nil }.count)
        return (due, new)
    }

    /// New cards spread between reviews so a session never front-loads them.
    private static func interleave(_ due: [Card], _ new: [Card]) -> [Card] {
        guard !due.isEmpty, !new.isEmpty else { return due + new }
        var out: [Card] = []
        let every = max(1, due.count / new.count)
        var d = due[...], n = new[...]
        while !d.isEmpty || !n.isEmpty {
            for _ in 0..<every { if let c = d.popFirst() { out.append(c) } }
            if let c = n.popFirst() { out.append(c) }
        }
        return out
    }
}

// MARK: - A running flashcard session

@Observable
final class StudySession: Identifiable {
    let id = UUID()
    let title: String
    let direction: StudyDirection
    private(set) var queue: [Card]
    private(set) var firstGrades: [String: Grade] = [:]
    private(set) var order: [String] = []
    private(set) var newIDs: Set<String> = []
    private(set) var reviews = 0
    var flipped = false
    let started = Date.now
    private(set) var finished: Date?
    let total: Int

    @ObservationIgnored private let store: ProgressStore

    init(title: String, cards: [Card], direction: StudyDirection = .recognition, store: ProgressStore) {
        self.title = title
        self.direction = direction
        self.queue = cards
        self.store = store
        self.total = cards.count
        newIDs = Set(cards.filter { store.state($0.id) == nil }.map(\.id))
    }

    var current: Card? { queue.first }
    var isDone: Bool { queue.isEmpty }
    var position: Int { min(total, order.count + (isDone ? 0 : 1)) }
    /// Missed cards waiting in the queue for another try.
    var repeats: Int { queue.filter { firstGrades[$0.id] != nil }.count }

    /// Direction actually used for this card — only words support all three.
    func direction(for card: Card) -> StudyDirection {
        card.kind == .vocab || card.kind == .kana ? direction : .recognition
    }

    func label(_ g: Grade) -> String {
        guard let c = current else { return "" }
        return Scheduler.label(store.state(c.id), g)
    }

    func grade(_ g: Grade) {
        guard let card = queue.first else { return }
        let next = store.grade(card, g)
        reviews += 1
        if firstGrades[card.id] == nil {
            firstGrades[card.id] = g
            order.append(card.id)
        }
        queue.removeFirst()
        flipped = false
        // Only a miss repeats inside the session; Good/Easy/Hard move on and
        // the scheduler brings the card back later.
        if g == .again, next.due.timeIntervalSinceNow < 15 * 60 {
            queue.insert(card, at: min(queue.count, 3))
        }
        if queue.isEmpty { finish() }
    }

    func finish() {
        guard finished == nil else { return }
        finished = .now
        store.addStudyTime(Int(Date.now.timeIntervalSince(started)))
    }

    // Results
    var seen: Int { order.count }
    var correct: Int { firstGrades.values.filter { $0 != .again }.count }
    var accuracy: Double { seen == 0 ? 0 : Double(correct) / Double(seen) }
    var missed: [Card] { order.filter { firstGrades[$0] == .again }.compactMap { DB.shared.card($0) } }
    var learnedNew: Int { order.filter { newIDs.contains($0) }.count }
    var duration: TimeInterval { (finished ?? .now).timeIntervalSince(started) }
}
