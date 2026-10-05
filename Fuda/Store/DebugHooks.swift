import Foundation

#if DEBUG && os(iOS)
/// Launch-argument hooks for screenshots / UI checks (Debug builds only):
///   -FudaSkipOnboarding YES   -FudaDemo YES   -FudaTab decks
///   -FudaOpen study|studyFlip|quiz|lesson|kanji|grammar
enum DebugHooks {
    static func apply(store: ProgressStore, router: Router) {
        let d = UserDefaults.standard
        if d.bool(forKey: "FudaSkipOnboarding") { store.settings.onboarded = true }
        if d.bool(forKey: "FudaDemo"), store.states.isEmpty { seed(store) }
        if let t = d.string(forKey: "FudaTab"), let tab = Router.Tab(rawValue: t) { router.tab = tab }
        switch d.string(forKey: "FudaOpen") {
        case "study", "studyFlip":
            let cards = Catalog.lessons()[3].cards.filter { ["食べる", "起きる", "会う", "飲む"].contains($0.prompt) }
            router.startStudy("まいにちの動詞 · Verbs", cards: cards, store: store)
            if d.string(forKey: "FudaOpen") == "studyFlip" { router.study?.flipped = true }
        case "kanji":
            router.startStudy("Kanji", cards: [DB.shared.kanjiCard("食")!], store: store)
            router.study?.flipped = true
        case "grammar":
            router.startStudy("Grammar", cards: [DB.shared.grammarCard("n5.e.tai")!], store: store)
            router.study?.flipped = true
        case "lesson":
            router.tab = .decks
            router.decksPath.append(Catalog.lessons()[3])
        case "kanaChart":
            router.tab = .decks
            router.decksPath.append(DecksRoute.kanaChart)
        case "complete":
            router.startStudy("まいにちの動詞", cards: Array(Catalog.lessons()[3].cards.suffix(6)), store: store)
            var n = 0
            while let s = router.study, !s.isDone, n < 40 { s.grade(n % 5 == 0 ? .again : .good); n += 1 }
        case "quiz":
            router.startQuiz("Lesson 4 quiz", cards: Catalog.lessons()[3].cards, store: store)
        default: break
        }
    }

    /// Plausible history: ~5 weeks of reviews over the first N5 lessons.
    private static func seed(_ store: ProgressStore) {
        let path = DB.shared.path(.n5)
        let cal = Calendar.current
        var rng = SystemRandomNumberGenerator()
        for (i, card) in path.prefix(260).enumerated() {
            let daysAgo = max(1, 36 - i / 8)
            var t = cal.date(byAdding: .day, value: -daysAgo, to: .now)!
            store.grade(card, .good, now: t)
            store.grade(card, .good, now: t.addingTimeInterval(700))
            var reviews = Int.random(in: 0...4, using: &rng)
            while reviews > 0, let s = store.state(card.id), s.due < .now.addingTimeInterval(-3600) {
                t = s.due
                store.grade(card, Int.random(in: 0...9, using: &rng) == 0 ? .again : .good, now: t)
                if store.state(card.id)?.phase == .relearning { store.grade(card, .good, now: t.addingTimeInterval(700)) }
                reviews -= 1
            }
        }
        store.toggleStar("v:食べる_たべる")
        store.toggleStar("k:会")
    }
}
#endif
