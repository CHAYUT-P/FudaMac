import Foundation
import Observation

struct Settings: Codable, Equatable {
    var level: Level = .n5
    var newPerDay = 10
    var sessionSize = 20
    var showFurigana = true
    var showRomaji = false
    var showEnglish = true
    var autoAudio = true
    var speechRate: Double = 0.42
    var appearance: Appearance = .system
    var reminderOn = false
    var reminderHour = 20
    var reminderMinute = 0
    var onboarded = false
    var talkTranslate = true

    init() {}

    // Missing keys fall back to defaults, so new settings never reset old ones.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let base = Settings()
        func v<T: Decodable>(_ k: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? fallback }
        level = v(.level, base.level)
        newPerDay = v(.newPerDay, base.newPerDay)
        sessionSize = v(.sessionSize, base.sessionSize)
        showFurigana = v(.showFurigana, base.showFurigana)
        showRomaji = v(.showRomaji, base.showRomaji)
        showEnglish = v(.showEnglish, base.showEnglish)
        autoAudio = v(.autoAudio, base.autoAudio)
        speechRate = v(.speechRate, base.speechRate)
        appearance = v(.appearance, base.appearance)
        reminderOn = v(.reminderOn, base.reminderOn)
        reminderHour = v(.reminderHour, base.reminderHour)
        reminderMinute = v(.reminderMinute, base.reminderMinute)
        onboarded = v(.onboarded, base.onboarded)
        talkTranslate = v(.talkTranslate, base.talkTranslate)
    }
}

struct ListMark: Codable, Hashable {
    var right = 0
    var wrong = 0
    var last = false
    var date = Date.now
}

struct DayStat: Codable, Hashable {
    var reviews = 0
    var correct = 0
    var newCards = 0
    var seconds = 0
}

/// Everything the learner owns: per-card SRS state, stars, quiz misses,
/// daily stats and settings. Persisted as one JSON file.
@Observable
final class ProgressStore {
    private struct Snapshot: Codable {
        var states: [String: CardState] = [:]
        var starred: Set<String> = []
        var quizMisses: [String: Int] = [:]
        var days: [String: DayStat] = [:]
        var settings = Settings()
        var talkBest: [String: Int] = [:]
        var talkSeen: Set<String> = []
        var listMarks: [String: ListMark] = [:]

        init(states: [String: CardState], starred: Set<String>, quizMisses: [String: Int], days: [String: DayStat],
             settings: Settings, talkBest: [String: Int], talkSeen: Set<String>, listMarks: [String: ListMark]) {
            self.states = states; self.starred = starred; self.quizMisses = quizMisses; self.days = days
            self.settings = settings; self.talkBest = talkBest; self.talkSeen = talkSeen
            self.listMarks = listMarks
        }

        // Every field optional on read, so adding fields never wipes old progress.
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            states = try c.decodeIfPresent([String: CardState].self, forKey: .states) ?? [:]
            starred = try c.decodeIfPresent(Set<String>.self, forKey: .starred) ?? []
            quizMisses = try c.decodeIfPresent([String: Int].self, forKey: .quizMisses) ?? [:]
            days = try c.decodeIfPresent([String: DayStat].self, forKey: .days) ?? [:]
            settings = (try? c.decodeIfPresent(Settings.self, forKey: .settings)) ?? Settings()
            talkBest = try c.decodeIfPresent([String: Int].self, forKey: .talkBest) ?? [:]
            talkSeen = try c.decodeIfPresent(Set<String>.self, forKey: .talkSeen) ?? []
            listMarks = (try? c.decodeIfPresent([String: ListMark].self, forKey: .listMarks)) ?? [:]
        }
    }

    private(set) var states: [String: CardState] = [:]
    private(set) var starred: Set<String> = []
    private(set) var quizMisses: [String: Int] = [:]
    private(set) var days: [String: DayStat] = [:]
    private(set) var talkBest: [String: Int] = [:]     // scene id → best role-play %
    private(set) var talkSeen: Set<String> = []
    private(set) var listMarks: [String: ListMark] = [:]   // vocab id → typed-meaning results (word list)
    var settings = Settings() { didSet { if settings != oldValue { save() } } }

    @ObservationIgnored private let url: URL
    @ObservationIgnored private var saveWork: DispatchWorkItem?

    init(filename: String = "progress.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url) {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .secondsSince1970
            if let s = try? dec.decode(Snapshot.self, from: data) {
                states = s.states; starred = s.starred; quizMisses = s.quizMisses; days = s.days; settings = s.settings
                talkBest = s.talkBest; talkSeen = s.talkSeen; listMarks = s.listMarks
            }
        }
    }

    // MARK: Queries

    func state(_ id: String) -> CardState? { states[id] }
    func mastery(_ id: String) -> Mastery { states[id]?.mastery ?? .new }
    func isStarred(_ id: String) -> Bool { starred.contains(id) }

    func isDue(_ id: String, now: Date = .now) -> Bool {
        guard let s = states[id] else { return false }
        return s.due <= now
    }

    /// All cards due now (learning cards whose step elapsed + reviews due today).
    func dueCards(now: Date = .now, level: Level? = nil) -> [Card] {
        let db = DB.shared
        return states.filter { $0.value.due <= now }
            .sorted { $0.value.due < $1.value.due }
            .compactMap { db.card($0.key) }
            .filter { level == nil || $0.level == nil || $0.level == level }
    }

    func dueCount(now: Date = .now) -> Int { states.values.filter { $0.due <= now }.count }

    func dueCount(on day: Date) -> Int {
        let cal = Calendar.current
        return states.values.filter { cal.isDate($0.due, inSameDayAs: day) }.count
    }

    var weakCards: [Card] {
        let ids = Set(states.filter { $0.value.lapses >= 3 }.map(\.key)).union(quizMisses.filter { $0.value >= 2 }.map(\.key))
        return ids.compactMap { DB.shared.card($0) }.sorted { (states[$0.id]?.lapses ?? 0) > (states[$1.id]?.lapses ?? 0) }
    }

    var starredCards: [Card] { starred.compactMap { DB.shared.card($0) }.sorted { $0.id < $1.id } }

    func counts(_ cards: [Card]) -> [Mastery: Int] {
        var out: [Mastery: Int] = [.new: 0, .learning: 0, .young: 0, .mature: 0]
        for c in cards { out[mastery(c.id), default: 0] += 1 }
        return out
    }

    /// Share of cards at least "young" (graduated) — used for progress meters.
    func learnedFraction(_ cards: [Card]) -> Double {
        guard !cards.isEmpty else { return 0 }
        return Double(cards.filter { mastery($0.id) >= .young }.count) / Double(cards.count)
    }

    func seenFraction(_ cards: [Card]) -> Double {
        guard !cards.isEmpty else { return 0 }
        return Double(cards.filter { states[$0.id] != nil }.count) / Double(cards.count)
    }

    // MARK: Days & streak

    static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func stat(on date: Date) -> DayStat { days[Self.dayKey.string(from: date)] ?? DayStat() }
    var today: DayStat { stat(on: .now) }
    var newRemainingToday: Int { max(0, settings.newPerDay - today.newCards) }

    var streak: Int {
        let cal = Calendar.current
        var d = cal.startOfDay(for: .now)
        if stat(on: d).reviews == 0 { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while stat(on: d).reviews > 0 {
            n += 1
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    var bestStreak: Int {
        let keys = days.filter { $0.value.reviews > 0 }.keys.compactMap { Self.dayKey.date(from: $0) }.sorted()
        var best = 0, run = 0
        var prev: Date?
        let cal = Calendar.current
        for d in keys {
            if let p = prev, cal.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run); prev = d
        }
        return best
    }

    var totalReviews: Int { days.values.reduce(0) { $0 + $1.reviews } }
    var totalSeconds: Int { days.values.reduce(0) { $0 + $1.seconds } }

    // MARK: Mutations

    @discardableResult
    func grade(_ card: Card, _ grade: Grade, now: Date = .now) -> CardState {
        let wasNew = states[card.id] == nil
        let next = Scheduler.next(states[card.id], grade, now: now)
        states[card.id] = next
        let key = Self.dayKey.string(from: now)
        var d = days[key] ?? DayStat()
        d.reviews += 1
        if grade != .again { d.correct += 1 }
        if wasNew { d.newCards += 1 }
        days[key] = d
        save()
        return next
    }

    func addStudyTime(_ seconds: Int) {
        guard seconds > 0 else { return }
        let key = Self.dayKey.string(from: .now)
        var d = days[key] ?? DayStat()
        d.seconds += min(seconds, 3600)
        days[key] = d
        save()
    }

    func recordQuiz(_ card: Card, correct: Bool) {
        if correct {
            if let n = quizMisses[card.id] { quizMisses[card.id] = n > 1 ? n - 1 : nil }
        } else {
            quizMisses[card.id, default: 0] += 1
        }
        save()
    }

    func toggleStar(_ id: String) {
        if starred.contains(id) { starred.remove(id) } else { starred.insert(id) }
        save()
    }

    func markTalkSeen(_ id: String) {
        guard !talkSeen.contains(id) else { return }
        talkSeen.insert(id)
        save()
    }

    func recordTalk(_ id: String, percent: Int) {
        talkSeen.insert(id)
        talkBest[id] = max(talkBest[id] ?? 0, percent)
        save()
    }

    func recordList(_ id: String, correct: Bool) {
        var m = listMarks[id] ?? ListMark()
        if correct { m.right += 1 } else { m.wrong += 1 }
        m.last = correct
        m.date = .now
        listMarks[id] = m
        save()
    }

    /// "I was right": the checker rejected an answer the learner knows was fine.
    func fixListMark(_ id: String) {
        guard var m = listMarks[id], !m.last else { return }
        m.wrong = max(0, m.wrong - 1)
        m.right += 1
        m.last = true
        listMarks[id] = m
        save()
    }

    /// Share of words whose most recent typed answer was right.
    func listKnown(_ ids: [String]) -> Int { ids.filter { listMarks[$0]?.last == true }.count }

    func reset() {
        states = [:]; starred = []; quizMisses = [:]; days = [:]; talkBest = [:]; talkSeen = []; listMarks = [:]
        save()
    }

    /// Marks cards as already known (e.g. the kana for a learner who can read).
    func markKnown(_ cards: [Card]) {
        let now = Date.now
        for c in cards where states[c.id] == nil {
            var s = Scheduler.next(nil, .easy, now: now)
            s.reps = 0
            states[c.id] = s
        }
        save()
    }

    // MARK: Persistence (debounced)

    private func save() {
        saveWork?.cancel()
        let snap = Snapshot(states: states, starred: starred, quizMisses: quizMisses, days: days,
                            settings: settings, talkBest: talkBest, talkSeen: talkSeen, listMarks: listMarks)
        let url = url
        let work = DispatchWorkItem {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .secondsSince1970
            if let data = try? enc.encode(snap) { try? data.write(to: url, options: .atomic) }
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func flush() {
        saveWork?.perform()
        saveWork = nil
    }
}
