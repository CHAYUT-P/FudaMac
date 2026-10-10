import SwiftUI

// MARK: - 札 Decks

struct MacDecksView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router
    @State private var shelf: Shelf = .vocab
    @State private var grouping: VocabGrouping = .lesson
    @State private var selected: Category?
    @State private var direction: StudyDirection = .recognition

    var body: some View {
        let level = store.settings.level
        let cats = Catalog.categories(shelf, level: level, grouping: grouping)
        let cur = selected.flatMap { s in cats.first { $0.id == s.id } } ?? cats.first
        HStack(spacing: 0) {
            ListColumn(width: 320) {
                VStack(alignment: .leading, spacing: 10) {
                    TrackedLabel(text: "札 · Decks")
                    Segmented(options: Shelf.allCases.map { ($0, $0.kind.ja) }, selection: Binding(get: { shelf }, set: { shelf = $0; selected = nil }), height: 34, fill: true)
                    if shelf == .vocab && level == .n5 {
                        Segmented(options: [(VocabGrouping.lesson, "By lesson"), (.type, "By word type")], selection: Binding(get: { grouping }, set: { grouping = $0; selected = nil }), height: 28, fill: true)
                    }
                    HStack(spacing: 6) {
                        smart("Due \(store.dueCount())", accent: true) { router.startStudy("Due · 復習", cards: Array(store.dueCards().prefix(store.settings.sessionSize)), store: store) }
                        smart("Weak \(store.weakCards.count)") { router.startStudy("Weak cards", cards: Array(store.weakCards.prefix(20)), store: store) }
                        smart("★ \(store.starredCards.count)") { router.startStudy("Starred", cards: SessionBuilder.cram(store.starredCards, store), store: store) }
                    }
                }
                .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 8)
                ForEach(cats) { c in
                    let learned = store.learnedFraction(c.cards)
                    Button { selected = c } label: {
                        HStack(spacing: 12) {
                            Text(c.glyph).font(Typo.mincho(c.glyph.count > 1 ? 13 : 18)).lineLimit(1).minimumScaleFactor(0.5)
                                .frame(width: 38, height: 38)
                                .foregroundStyle(learned >= 1 ? Ink.onInk : Ink.ink)
                                .background { ZStack { if learned >= 1 { Ink.ink } else { Ink.paper; if learned > 0 { Screentone(density: 0.2 + learned * 0.5, spacing: 4) } } } }
                                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                            VStack(alignment: .leading, spacing: 1) {
                                MixedText(c.ja, size: 15, weight: .bold, color: cur?.id == c.id ? Ink.onInk : Ink.ink)
                                Text(c.ja == c.en ? c.caption : "\(c.caption) · \(c.en)").font(Typo.ui(11)).opacity(0.75).lineLimit(1)
                            }
                            Spacer()
                            let due = c.cards.filter { store.isDue($0.id) }.count
                            if due > 0 { Text("\(due)").font(Typo.ui(11, .heavy)).foregroundStyle(Ink.akane) }
                        }
                        .padding(.horizontal, 10).frame(minHeight: 52).padding(.vertical, 2)
                        .foregroundStyle(cur?.id == c.id ? Ink.onInk : Ink.ink)
                        .background(cur?.id == c.id ? Ink.ink : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).padding(.horizontal, 12)
                }
            }
            if let c = cur { deckDetail(c) }
        }
    }

    private func smart(_ t: String, accent: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(Typo.ui(12, .heavy)).padding(.horizontal, 8).frame(height: 28)
                .foregroundStyle(accent ? Ink.akane : Ink.ink)
                .overlay(Rectangle().strokeBorder(accent ? Ink.akane : Ink.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func deckDetail(_ c: Category) -> some View {
        let cards = c.cards
        let plan = SessionBuilder.newCount(cards, store)
        return VStack(alignment: .leading, spacing: 16) {
            PaneHeader(kicker: c.caption, title: c.ja, subtitle: c.en) {
                HStack(spacing: 10) {
                    if c.cards.first?.kind == .vocab || c.cards.first?.kind == .kana {
                        Segmented(options: StudyDirection.allCases.map { ($0, $0.ja) }, selection: $direction, height: 40)
                    }
                    Button("試 Quiz") { router.startQuiz("Quiz · \(c.ja)", cards: cards, count: 15, store: store) }
                        .buttonStyle(InkButtonStyle(kind: .outline, height: 46)).frame(width: 100)
                    Button { router.startStudy(c.ja, cards: SessionBuilder.deck(cards, store), direction: direction, store: store) } label: {
                        Text(plan.due + plan.new > 0 ? "Study \(plan.due + plan.new) →" : "Review again →").padding(.horizontal, 16)
                    }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 46)).fixedSize()
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            MacMasteryStrip(counts: store.counts(cards))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(c.sections) { s in
                        HStack {
                            Text(s.title).font(Typo.ui(13, .heavy))
                            Text(s.subtitle).font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(1)
                            Spacer()
                            Button("Study section") { router.startStudy("\(c.ja) · \(s.title)", cards: SessionBuilder.deck(s.cards, store), direction: direction, store: store) }
                                .buttonStyle(.plain).font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane)
                        }
                        .padding(.top, 16).padding(.bottom, 4)
                        ForEach(s.cards) { MacCardRow(card: $0) }
                    }
                }
            }
        }
        .padding(30)
    }
}

// MARK: - 練 Practice

struct MacPracticeView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router

    var body: some View {
        let level = store.settings.level
        let db = DB.shared
        let seen = store.states.keys.compactMap { db.card($0) }.filter { $0.level == level }
        let pool = { (c: [Card]) -> [Card] in c.count >= 8 ? c : Array(db.path(level).prefix(60)) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(kicker: "練習 · Practice", title: "Drills", subtitle: "Quizzes use cards you've already met. Every wrong answer counts toward Weak cards.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    drill("試", "Mixed quiz", "15 questions: meaning, reading, listening, grammar", accent: true) { router.startQuiz("Mixed quiz · \(level.title)", cards: pool(seen), count: 15, store: store) }
                    drill("聴", "Listening", "Hear a word, pick it · 10 questions") { router.startQuiz("Listening", cards: pool(seen.filter { $0.kind == .vocab }), mode: .listening, store: store) }
                    drill("語", "Vocabulary sprint", "20 words from the whole \(level.title) list") { router.startQuiz("Vocab sprint", cards: db.vocab(level), count: 20, store: store) }
                    drill("漢", "Kanji", "Readings and meanings · \(db.kanji(level).count) kanji") { router.startQuiz("Kanji quiz", cards: db.kanji(level), count: 12, store: store) }
                    drill("文", "Grammar check", "Fill-in questions from Tone's exercises") { router.startQuiz("Grammar check", cards: db.grammar(level), count: 10, store: store) }
                    drill("あ", "Hiragana", "15 questions") { router.startQuiz("Hiragana", cards: KanaData.all.filter { $0.script == .hira }.map(Card.kana), count: 15, store: store) }
                    drill("ア", "Katakana", "15 questions") { router.startQuiz("Katakana", cards: KanaData.all.filter { $0.script == .kata }.map(Card.kana), count: 15, store: store) }
                    drill("弱", "Weak cards", store.weakCards.isEmpty ? "None yet" : "\(store.weakCards.count) cards to strengthen", disabled: store.weakCards.isEmpty) { router.startStudy("Weak cards", cards: Array(store.weakCards.prefix(20)), store: store) }
                    drill("★", "Starred", store.starredCards.isEmpty ? "Star any card to save it here" : "\(store.starredCards.count) saved cards", disabled: store.starredCards.isEmpty) { router.startStudy("Starred", cards: SessionBuilder.cram(store.starredCards, store), store: store) }
                }
            }
            .padding(30)
        }
    }

    private func drill(_ glyph: String, _ title: String, _ sub: String, accent: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(glyph).font(Typo.mincho(26)).frame(width: 54, height: 54)
                    .foregroundStyle(accent ? Ink.onAkane : Ink.ink).background(accent ? Ink.akane : Ink.paper)
                    .overlay(Rectangle().strokeBorder(accent ? Ink.akane : Ink.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typo.ui(16, .heavy))
                    Text(sub).font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(2)
                }
                Spacer()
                Text("›").font(.system(size: 20, weight: .heavy)).foregroundStyle(accent ? Ink.akane : Ink.ink)
            }
            .padding(14).inkBox().contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.5 : 1)
    }
}

// MARK: - 辞 Dictionary

struct MacDictionaryView: View {
    @Environment(MacRouter.self) private var router
    @FocusState private var focused: Bool
    @State private var detail: Card?

    var body: some View {
        @Bindable var router = router
        let results = DB.shared.search(router.query, level: nil)
        let lessons = Textbook.search(router.query)
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                PaneHeader(kicker: "辞書 · Dictionary", title: "Search everything", subtitle: "Kanji, kana, romaji, Thai or English across N5 and N4")
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Ink.soft)
                    TextField("食べる, taberu, กิน, eat…", text: $router.query)
                        .textFieldStyle(.plain).font(Typo.ui(18)).focused($focused)
                }
                .padding(.horizontal, 14).frame(height: 50).inkBox()
                if router.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Try 駅, あう, kau, อาหาร, or station.").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                    Spacer()
                } else if results.isEmpty && lessons.isEmpty {
                    Text("No matches").font(Typo.ui(15, .heavy)).padding(.top, 20)
                    Spacer()
                } else {
                    TrackedLabel(text: "\(results.count + lessons.count) results")
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if !lessons.isEmpty {
                                TrackedLabel(text: "文法 · explained in the course", color: Ink.ink).padding(.vertical, 6)
                                ForEach(lessons.prefix(12)) { h in
                                    Button {
                                        router.notesSection = h.section
                                        router.openLesson(h.lesson, step: .notes)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text("L\(h.lesson)").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.onAkane)
                                                .frame(width: 40, height: 26).background(Ink.akane)
                                            VStack(alignment: .leading, spacing: 1) {
                                                MixedText(h.titleJA, size: 16, weight: .bold)
                                                Text(h.titleTH).font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(1)
                                            }
                                            Spacer()
                                            Text("Open notes →").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane)
                                        }
                                        .padding(.vertical, 8)
                                        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                if !results.isEmpty { TrackedLabel(text: "Cards").padding(.top, 16).padding(.bottom, 6) }
                            }
                            ForEach(results) { c in
                                Button { detail = c } label: { MacCardRow(card: c).background(detail?.id == c.id ? Ink.chip : .clear).contentShape(Rectangle()) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            if let d = detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Tag(text: d.badge); Spacer(); SpeakIcon(text: d.speech) }
                        MacCardBack(card: d)
                    }
                    .padding(24)
                }
                .frame(width: 640)
                .background(Ink.card)
                .overlay(alignment: .leading) { Rectangle().fill(Ink.ink).frame(width: 2) }
            }
        }
        .onAppear { focused = true }
    }
}

// MARK: - 績 Progress

struct MacProgressView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course

    var body: some View {
        let level = store.settings.level
        let rows: [(String, String, [Card])] = [("語彙", "Vocab", DB.shared.vocab(level)), ("漢字", "Kanji", DB.shared.kanji(level)), ("文法", "Grammar", DB.shared.grammar(level)), ("かな", "Kana", DB.shared.kana.map(Card.kana))]
        let core = rows.prefix(3).flatMap(\.2)
        let pct = core.isEmpty ? 0 : Int(Double(core.filter { store.mastery($0.id) >= .young }.count) / Double(core.count) * 100)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PaneHeader(kicker: "成績 · Progress", title: "JLPT \(level.title)")
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(pct)%").font(Typo.mincho(90))
                            Text("of \(level.title) learned").font(Typo.ui(15, .bold)).foregroundStyle(Ink.soft)
                        }
                        ForEach(rows, id: \.1) { ja, en, cards in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { (Text(ja).font(Typo.mincho(14)) + Text("  \(en)").font(Typo.ui(14, .heavy))); Spacer(); Text("\(cards.filter { store.mastery($0.id) >= .young }.count) / \(cards.count)").font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft) }
                                MacMasteryStrip(counts: store.counts(cards), height: 14)
                            }
                        }
                    }
                    .padding(22).frame(maxWidth: .infinity).inkBox()
                    VStack(alignment: .leading, spacing: 12) {
                        TrackedLabel(text: "Course", color: Ink.ink)
                        let lessons = Course.shared.lessons
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: 6), alignment: .leading, spacing: 6) {
                            ForEach(lessons) { l in
                                let passed = course.passed(l.n), started = course.doneCount(l.n) > 0
                                Text("\(l.n)").font(Typo.ui(13, .heavy)).frame(width: 44, height: 44)
                                    .foregroundStyle(passed ? Ink.onInk : Ink.ink)
                                    .background { ZStack { if passed { Ink.ink } else if started { Screentone(density: 0.3 + Double(course.doneCount(l.n)) / 10, spacing: 4) } } }
                                    .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                                    .help("Lesson \(l.n) · \(l.ja)")
                            }
                        }
                        Text("\(lessons.filter { course.passed($0.n) }.count) of \(lessons.count) lessons stamped 済 · \(course.stories.count) stories read · \(course.talks.count) conversations · \(course.essentials.count) essentials")
                            .font(Typo.ui(12)).foregroundStyle(Ink.soft)
                    }
                    .padding(22).frame(width: 360).inkBox()
                }
                HStack(spacing: 0) {
                    total("\(store.streak)", "day streak")
                    Rectangle().fill(Ink.ink).frame(width: 2)
                    total("\(store.totalReviews)", "reviews")
                    Rectangle().fill(Ink.ink).frame(width: 2)
                    total("\(store.totalSeconds / 3600)h \((store.totalSeconds % 3600) / 60)m", "studied")
                    Rectangle().fill(Ink.ink).frame(width: 2)
                    total("\(store.states.count)", "cards met")
                }
                .fixedSize(horizontal: false, vertical: true).inkBox()
                heatmap
            }
            .padding(30)
        }
    }

    private func total(_ big: String, _ small: String) -> some View {
        VStack(spacing: 2) { Text(big).font(Typo.mincho(26)); Text(small).font(Typo.ui(11, .bold)).foregroundStyle(Ink.soft) }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
    }

    private var heatmap: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let wd = (cal.component(.weekday, from: today) + 5) % 7
        let start = cal.date(byAdding: .day, value: -(25 * 7 + wd), to: today)!
        return VStack(alignment: .leading, spacing: 8) {
            TrackedLabel(text: "Last 26 weeks", color: Ink.ink)
            HStack(spacing: 3) {
                ForEach(0..<26, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { d in
                            let day = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                            let n = store.stat(on: day).reviews
                            ZStack { if day > today { Color.clear } else if n >= 60 { Ink.ink } else if n >= 25 { Screentone(density: 0.8, spacing: 3) } else if n > 0 { Screentone(density: 0.4, spacing: 3) } }
                                .frame(width: 16, height: 16)
                                .overlay(Rectangle().strokeBorder(day == today ? Ink.akane : n > 0 ? Ink.ink : Ink.line, lineWidth: day == today ? 2 : 1))
                                .help("\(day.formatted(date: .abbreviated, time: .omitted)) · \(n) reviews")
                        }
                    }
                }
            }
        }
        .padding(22).inkBox()
    }
}

// MARK: - Settings (⌘,)

struct MacSettingsView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @State private var confirm = false

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Study") {
                Picker("Level", selection: $store.settings.level) { ForEach(Level.allCases) { Text($0.title).tag($0) } }
                Stepper("New cards per day: \(store.settings.newPerDay)", value: $store.settings.newPerDay, in: 0...50, step: 5)
                Picker("Cards per session", selection: $store.settings.sessionSize) { ForEach([10, 20, 30], id: \.self) { Text("\($0)").tag($0) } }
            }
            Section("Cards") {
                Toggle("Furigana", isOn: $store.settings.showFurigana)
                Toggle("Romaji", isOn: $store.settings.showRomaji)
                Toggle("English beside Thai", isOn: $store.settings.showEnglish)
                Toggle("Auto-play audio", isOn: $store.settings.autoAudio)
                Slider(value: $store.settings.speechRate, in: 0.3...0.55) { Text("Voice speed") }
            }
            Section("Appearance") {
                Picker("Theme", selection: $store.settings.appearance) { ForEach(Appearance.allCases) { Text($0.title).tag($0) } }
            }
            Section("Data") {
                Button("Reset all progress…", role: .destructive) { confirm = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Erase every review, streak, star and lesson stamp?", isPresented: $confirm) {
            Button("Reset progress", role: .destructive) { store.reset(); course.reset() }
        }
    }
}
