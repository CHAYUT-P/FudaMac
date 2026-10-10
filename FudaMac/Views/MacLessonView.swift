import SwiftUI

struct MacLessonView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            header
            Group {
                let tb = lesson.isKana ? nil : Textbook.lesson(lesson.n)
                switch router.step {
                case .learn:
                    if lesson.isKana { KanaLearnView(lesson: lesson) }
                    else if let tb { TextbookBookView(lesson: lesson, tb: tb) }
                    else { LearnStepView(lesson: lesson) }
                case .video:
                    if let tb { TextbookVideoView(lesson: lesson, tb: tb) } else { LearnStepView(lesson: lesson) }
                case .notes:
                    if let tb { TextbookNotesView(lesson: lesson, tb: tb) } else { LearnStepView(lesson: lesson) }
                case .words: CardsStepView(lesson: lesson, step: .words)
                case .kanji: CardsStepView(lesson: lesson, step: .kanji)
                case .talk: TalkStepView(lesson: lesson)
                case .read: ReadStepView(lesson: lesson)
                case .practice:
                    if let tb { TextbookDrillsView(lesson: lesson, tb: tb) } else { PracticeStepView(lesson: lesson) }
                case .test: TestStepView(lesson: lesson)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id("\(lesson.n)-\(router.step.rawValue)")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Button { router.lessonN = nil } label: { Text("‹ Course").font(Typo.ui(13, .bold)) }
                    .buttonStyle(.plain).keyboardShortcut(router.typing ? nil : KeyboardShortcut(.escape, modifiers: []))
                Text("LESSON \(lesson.n) · 第\(lesson.part.numeral)部").font(.system(size: 11, weight: .heavy)).tracking(2)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Ink.ink).foregroundStyle(Ink.onInk)
                MixedText(lesson.ja, size: 21, weight: .bold)
                Text(lesson.en).font(Typo.ui(14)).foregroundStyle(Ink.soft).lineLimit(1)
                Spacer()
                if course.passed(lesson.n) { StampBadge(text: "済", size: 34) }
                ReadingToggles()
            }
            HStack(spacing: 0) {
                let steps = LessonStep.steps(for: lesson.n)
                ForEach(Array(steps.enumerated()), id: \.element) { i, st in
                    let on = router.step == st
                    let done = course.isDone(lesson.n, st)
                    Button { router.step = st } label: {
                        HStack(spacing: 5) {
                            Text("\(i + 1)").font(Typo.ui(10, .heavy)).foregroundStyle(on ? Ink.akane : Ink.soft)
                            Text(st.ja(lesson.n)).font(Typo.mincho(16))
                            if steps.count <= 7 { Text(st.en(lesson.n)).font(Typo.ui(12, .heavy)) }
                            if done { Text("✓").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane) }
                        }
                        .padding(.horizontal, steps.count <= 7 ? 16 : 13).frame(height: 42)
                        .foregroundStyle(on ? Ink.ink : Ink.soft)
                        .background(on ? Ink.paper : .clear)
                        .overlay(alignment: .bottom) { Rectangle().fill(on ? Ink.akane : .clear).frame(height: 4) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(st.en(lesson.n)) · ⌥\(i + 1)")
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [.option])
                }
                Spacer()
            }
        }
        .padding(.horizontal, 30).padding(.top, 16)
        .background(Ink.card)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }
    }
}

// MARK: - Shared step chrome

struct StepFooter: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    let step: LessonStep
    var canMarkDone = true

    var body: some View {
        let done = course.isDone(lesson.n, step)
        let steps = LessonStep.steps(for: lesson.n)
        let next = steps.firstIndex(of: step).flatMap { $0 + 1 < steps.count ? steps[$0 + 1] : nil }
        HStack(spacing: 10) {
            if canMarkDone {
                Button {
                    course.complete(lesson.n, step)
                } label: { Text(done ? "✓ Step done" : "Mark step done").padding(.horizontal, 14) }
                    .buttonStyle(InkButtonStyle(kind: done ? .ink : .outline, height: 42)).fixedSize()
                    .disabled(done)
            }
            Spacer()
            if let next {
                Button { router.step = next } label: { Text("Next: \(next.ja(lesson.n)) \(next.en(lesson.n)) →").padding(.horizontal, 18) }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 42)).fixedSize()
                    .keyboardShortcut(router.typing ? nil : KeyboardShortcut(.rightArrow, modifiers: [.command]))
            }
        }
        .padding(.horizontal, 30).padding(.vertical, 12)
        .background(Ink.paper)
        .overlay(alignment: .top) { Rectangle().fill(Ink.ink).frame(height: 2) }
    }
}

// MARK: - Words / Kanji

struct CardsStepView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    let step: LessonStep
    @State private var direction: StudyDirection = .recognition

    var body: some View {
        let cards = step == .kanji ? lesson.kanjiCards : (lesson.isKana ? lesson.kanaCards : lesson.wordCards)
        let plan = SessionBuilder.newCount(cards, store)
        VStack(spacing: 0) {
            if cards.isEmpty {
                VStack(spacing: 10) {
                    Text(step == .kanji ? "漢" : "語").font(Typo.mincho(64)).foregroundStyle(Ink.line)
                    Text(step == .kanji ? "No new kanji in this lesson" : "No words in this lesson").font(Typo.ui(16, .heavy))
                    Text("Move on to the next step.").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 3) {
                                TrackedLabel(text: step == .kanji ? "漢字 · Kanji in this lesson" : "語彙 · Words in this lesson")
                                Text("\(cards.count) \(step == .kanji ? "kanji" : lesson.isKana ? "kana" : "words")").font(Typo.mincho(26))
                            }
                            Spacer()
                            MacMasteryStrip(counts: store.counts(cards), height: 14).frame(width: 260)
                        }
                        if step == .kanji {
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                                    ForEach(cards) { KanjiTile(card: $0) }
                                }
                            }
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(lesson.isKana ? [] : lesson.sections, id: \.self) { s in
                                        Text("\(s.en) · \(s.ids.count)").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.soft).padding(.top, 14).padding(.bottom, 4)
                                        ForEach(s.ids.compactMap { DB.shared.vocabCard($0) }) { MacCardRow(card: $0) }
                                    }
                                    if lesson.isKana { ForEach(cards) { MacCardRow(card: $0) } }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        TrackedLabel(text: "Study", color: Ink.ink)
                        if step == .words {
                            Segmented(options: StudyDirection.allCases.map { ($0, $0.en) }, selection: $direction, height: 34, fill: true)
                        }
                        Button {
                            router.startStudy("\(lesson.ja) · \(step.en)", cards: SessionBuilder.deck(cards, store), direction: direction, store: store)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(plan.due + plan.new > 0 ? "Study \(plan.due + plan.new) cards →" : "Review again →")
                                Text("\(plan.due) due + \(plan.new) new").font(Typo.ui(12, .medium)).opacity(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                        }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 58))
                        Button("試 Quiz these") { router.startQuiz("\(lesson.ja) · \(step.en)", cards: cards, count: min(15, cards.count), store: store) }
                            .buttonStyle(InkButtonStyle(kind: .outline, height: 44))
                        Text("Cards you study here join your daily reviews. This step is ticked when you've seen every card at least once.")
                            .font(Typo.ui(12)).foregroundStyle(Ink.soft)
                        HStack {
                            Text("Seen").font(Typo.ui(12, .bold))
                            Spacer()
                            Text("\(Int(store.seenFraction(cards) * 100))%").font(Typo.ui(12, .heavy))
                        }
                        DotMeter(value: store.seenFraction(cards), count: 14, size: 7)
                        Spacer()
                    }
                    .frame(width: 280)
                }
                .padding(30)
                .onAppear { if store.seenFraction(cards) >= 1 { course.complete(lesson.n, step) } }
                .onChange(of: store.seenFraction(cards)) { _, v in if v >= 1 { course.complete(lesson.n, step) } }
            }
            StepFooter(lesson: lesson, step: step)
        }
    }
}

struct KanjiTile: View {
    @Environment(ProgressStore.self) private var store
    let card: Card
    var body: some View {
        let k = card.kanjiItem!
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Path { p in p.move(to: CGPoint(x: 41, y: 0)); p.addLine(to: CGPoint(x: 41, y: 82)); p.move(to: CGPoint(x: 0, y: 41)); p.addLine(to: CGPoint(x: 82, y: 41)) }
                    .stroke(Ink.akane.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                Text(k.char).font(Typo.mincho(62))
            }
            .frame(width: 82, height: 82)
            .overlay(Rectangle().strokeBorder(Ink.akane, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(k.th).font(Typo.ui(15, .semibold)).lineLimit(1)
                Text(k.en).font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(1)
                Text("音 \(k.on.isEmpty ? "—" : k.on)").font(Typo.ui(12)).lineLimit(1)
                Text("訓 \(k.kun.isEmpty ? "—" : k.kun)").font(Typo.ui(12)).lineLimit(1)
                Text(k.examples.map { "\($0.w)（\($0.r)）" }.joined(separator: " · ")).font(Typo.mincho(12, bold: false)).foregroundStyle(Ink.soft).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .inkBox(store.mastery(card.id) >= .young ? Ink.chip : Ink.card)
        .overlay(alignment: .topTrailing) { SpeakIcon(text: k.reading, size: 24).padding(8) }
    }
}

// MARK: - Talk

struct TalkStepView: View {
    @Environment(CourseProgress.self) private var course
    let lesson: CourseLesson
    @State private var pick = 0

    var body: some View {
        let tb = Textbook.lesson(lesson.n)
        let dialogues = (tb.map { [$0.dialogue] } ?? []) + lesson.dialogues.compactMap { Course.shared.dialogue($0) }
        VStack(spacing: 0) {
            if dialogues.isEmpty {
                VStack(spacing: 10) {
                    Text("話").font(Typo.mincho(64)).foregroundStyle(Ink.line)
                    Text("No lesson conversation here").font(Typo.ui(16, .heavy))
                    Text("Try a real-life scene in Conversations instead.").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if dialogues.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(dialogues.indices, id: \.self) { i in
                            Button { pick = i } label: {
                                Text("\(i == 0 && tb != nil ? "本文 · " : "")\(dialogues[i].jaTitle)\(course.talks.contains(dialogues[i].key) ? "  済" : "")").font(Typo.mincho(14)).padding(.horizontal, 12).frame(height: 32)
                                    .foregroundStyle(pick == i ? Ink.onInk : Ink.ink).background(pick == i ? Ink.ink : .clear)
                                    .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 30).padding(.top, 14)
                }
                DialoguePlayer(dialogue: dialogues[min(pick, dialogues.count - 1)],
                               scene: pick == 0 ? tb?.conversation.sceneTH : nil) {
                    course.markTalk(dialogues[min(pick, dialogues.count - 1)].key)
                    if dialogues.allSatisfy({ course.talks.contains($0.key) }) { course.complete(lesson.n, .talk) }
                }
                .id(pick)
            }
            StepFooter(lesson: lesson, step: .talk)
        }
    }
}

/// A lesson dialogue: read it, listen, then role-play the learner's part.
struct DialoguePlayer: View {
    @Environment(ProgressStore.self) private var store
    let dialogue: LessonDialogue
    var scene: String? = nil
    var onComplete: () -> Void
    @State private var role = false
    @State private var turn = 0           // index into lines while role-playing
    @State private var revealed = false
    @State private var playing: Int?

    var body: some View {
        let you = dialogue.learnerSpeaker
        let lines = dialogue.lines
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        TrackedLabel(text: "話 · Lesson conversation")
                        MixedText(dialogue.jaTitle, size: 28)
                        Text("\(dialogue.englishTitle) · \(lines.count) lines · you are \(you)").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                    }
                    Spacer()
                    Segmented(options: [(false, "読む Read"), (true, "役 Role-play")], selection: Binding(get: { role }, set: { role = $0; turn = 0; revealed = false }), height: 34)
                }
                if let scene, !scene.isEmpty, !role {
                    HStack(alignment: .top, spacing: 10) {
                        Text("場面").font(.system(size: 11, weight: .heavy)).foregroundStyle(Ink.onInk).padding(.horizontal, 6).padding(.vertical, 3).background(Ink.ink)
                        MixedText(scene, size: 14).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Ink.chip)
                }
                if role {
                    Text("You are \(you). Read the other line, say yours out loud, then press Space to check.")
                        .font(Typo.ui(13, .bold)).foregroundStyle(Ink.akane)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(Rectangle().strokeBorder(Ink.akane, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                                if !role || i <= turn {
                                    bubble(line, index: i, mine: line.speaker == you, hidden: role && i == turn && line.speaker == you && !revealed)
                                        .id(i)
                                }
                            }
                            if role && turn >= lines.count - 1 && (revealed || lines.last?.speaker != you) {
                                HStack(spacing: 12) {
                                    StampBadge(text: "済")
                                    Text("Conversation complete").font(Typo.ui(15, .heavy))
                                    Spacer()
                                    Button("Again") { turn = 0; revealed = false }.buttonStyle(InkButtonStyle(kind: .outline, height: 38)).frame(width: 90)
                                }
                                .padding(.top, 8)
                                .onAppear(perform: onComplete)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: turn) { _, t in withAnimation { proxy.scrollTo(t, anchor: .bottom) } }
                }
                if role {
                    HStack {
                        Button {
                            advance(lines: lines, you: you)
                        } label: { HStack { Text(lines.indices.contains(turn) && lines[turn].speaker == you && !revealed ? "Check" : "Next line"); Kbd("Space", light: true) } }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 44))
                            .keyboardShortcut(.space, modifiers: [])
                            .disabled(turn >= lines.count - 1 && (revealed || lines.last?.speaker != you))
                    }
                } else {
                    HStack(spacing: 12) {
                        Button { playAll(from: 0) } label: { HStack { Image(systemName: "play.fill"); Text("Play all") } }
                            .buttonStyle(InkButtonStyle(kind: .ink, height: 42)).frame(width: 150)
                        Button("Stop") { Speech.shared.stop(); playing = nil }.buttonStyle(InkButtonStyle(kind: .outline, height: 42)).frame(width: 90)
                        Spacer()
                        Button("Done reading ✓") { onComplete() }.buttonStyle(InkButtonStyle(kind: .outline, height: 42)).frame(width: 160)
                    }
                }
            }
            .padding(30)
        }
        .onDisappear { Speech.shared.stop(); playing = nil }
    }

    private func advance(lines: [DialogueLine], you: String) {
        if lines.indices.contains(turn), lines[turn].speaker == you, !revealed {
            revealed = true
            Speech.shared.say(lines[turn].kana)
            return
        }
        guard turn < lines.count - 1 else { return }
        turn += 1
        revealed = false
        if lines[turn].speaker != you { Speech.shared.say(lines[turn].kana, voice: .partner) }
    }

    private func playAll(from i: Int) {
        guard i < dialogue.lines.count else { playing = nil; return }
        playing = i
        let line = dialogue.lines[i]
        Speech.shared.say(line.kana, voice: line.speaker == dialogue.learnerSpeaker ? .main : .partner) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if playing == i { playAll(from: i + 1) } }
        }
    }

    private func bubble(_ line: DialogueLine, index: Int, mine: Bool, hidden: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if mine { Spacer(minLength: 60) }
            if !mine { who(line.speaker, mine: false) }
            VStack(alignment: .leading, spacing: 3) {
                if hidden {
                    TrackedLabel(text: "Your turn · あなたの番", color: Ink.akane, size: 10)
                    Screentone(density: 0.4, spacing: 6, color: Ink.akane).frame(width: 260, height: 20)
                    Text("Say: \(line.th)").font(Typo.ui(13))
                    if store.settings.showEnglish { Text(line.en).font(Typo.ui(12)).foregroundStyle(Ink.soft) }
                } else {
                    SentenceBlock(ja: line.ja, kana: line.kana, romaji: line.romaji, th: line.th, en: line.en, size: 19)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: 520, alignment: .leading)
            .inkBox(Ink.card, border: hidden || playing == index ? Ink.akane : Ink.ink)
            .overlay(alignment: .topTrailing) { if !hidden { SpeakIcon(text: line.kana, size: 24).padding(6) } }
            if mine { who(line.speaker, mine: true) }
            if !mine { Spacer(minLength: 60) }
        }
    }

    private func who(_ s: String, mine: Bool) -> some View {
        Text(s).font(.system(size: 12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
            .frame(width: 56, height: 26)
            .foregroundStyle(mine ? Ink.onAkane : Ink.ink)
            .background(mine ? Ink.akane : Ink.chip)
    }
}

// MARK: - Read

struct ReadStepView: View {
    @Environment(CourseProgress.self) private var course
    let lesson: CourseLesson

    var body: some View {
        let stories = lesson.stories.compactMap { Course.shared.story($0) }
        VStack(spacing: 0) {
            if let story = stories.first {
                StoryReader(story: story) { score in
                    course.recordStory(story.key, score: score)
                    course.complete(lesson.n, .read)
                }
            } else {
                LessonReading(lesson: lesson)
            }
            StepFooter(lesson: lesson, step: .read)
        }
    }
}

/// Lessons without a story read their grammar examples as a short text.
struct LessonReading: View {
    let lesson: CourseLesson
    var body: some View {
        let sentences = lesson.grammarCards.compactMap(\.grammarItem).flatMap { $0.examples.prefix(2) }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    TrackedLabel(text: "読む · Lesson reading")
                    Text("Sentences built from this lesson").font(Typo.mincho(26))
                    Text("Read each one aloud, then check the translation.").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                }
                ForEach(Array(sentences.enumerated()), id: \.offset) { i, e in
                    HStack(alignment: .top, spacing: 14) {
                        Text(String(format: "%02d", i + 1)).font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane)
                        SentenceBlock(ja: e.ja, kana: e.kana, romaji: e.romaji, th: e.th, en: e.en, size: 20)
                        Spacer()
                        SpeakIcon(text: e.kana)
                    }
                    .padding(14).inkBox()
                }
            }
            .padding(30)
        }
    }
}

// MARK: - Practice (grammar exercises)

struct PracticeStepView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(ProgressStore.self) private var store
    let lesson: CourseLesson
    var showFooter = true
    @Environment(MacRouter.self) private var router
    @FocusState private var fieldFocused: Bool
    @State private var index = 0
    @State private var typed = ""
    @State private var picked: Int?
    @State private var checked = false
    @State private var score = 0

    var body: some View {
        let items = exercises
        VStack(spacing: 0) {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Text("練").font(Typo.mincho(64)).foregroundStyle(Ink.line)
                    Text("Practise with a quiz").font(Typo.ui(16, .heavy))
                    Text("This lesson has no written exercises, so practise with a mixed quiz instead.").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                    QuizLauncher(lesson: lesson)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if index >= items.count {
                VStack(spacing: 14) {
                    StampBadge(text: "済", size: 90)
                    Text("Practice complete · \(score) / \(items.count)").font(Typo.ui(18, .heavy))
                    Button("Practise again") { index = 0; score = 0; reset() }.buttonStyle(InkButtonStyle(kind: .outline, height: 42)).frame(width: 180)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { if showFooter { course.complete(lesson.n, .practice) } }
            } else {
                exercise(items[index], number: index + 1, total: items.count)
            }
            if showFooter { StepFooter(lesson: lesson, step: .practice, canMarkDone: false) }
        }
    }

    private var exercises: [(GrammarExercise, GrammarItem)] {
        lesson.grammarCards.compactMap(\.grammarItem).flatMap { g in g.exercises.map { ($0, g) } }
    }

    private func reset() { typed = ""; picked = nil; checked = false }

    private func isRight(_ e: GrammarExercise) -> Bool {
        if e.isChoice { return picked == e.answer }
        let norm = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "。", with: "").replacingOccurrences(of: " ", with: "") }
        return e.accepted.map(norm).contains(norm(typed))
    }

    private func exercise(_ item: (GrammarExercise, GrammarItem), number: Int, total: Int) -> some View {
        let (e, g) = item
        let right = checked && isRight(e)
        return HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    TrackedLabel(text: "練習 · Exercise \(number) of \(total)")
                    Spacer()
                    Text("Score \(score)").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
                }
                HStack(spacing: 3) {
                    ForEach(0..<total, id: \.self) { i in Rectangle().fill(i < number - 1 ? Ink.ink : i == number - 1 ? Ink.akane : Ink.line).frame(height: 5) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    MixedText(e.captionEN.isEmpty ? (e.isChoice ? "Choose the best answer" : "Type the answer (kana or kanji)") : e.captionEN, size: 13, weight: .heavy)
                    if !e.captionTH.isEmpty { MixedText(e.captionTH, size: 13, color: Ink.soft) }
                    if e.kana.isEmpty { MixedText(e.prompt, size: 30, weight: .bold) } else { JPText(ja: e.prompt, kana: e.kana, size: 32, bold: true) }
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading).inkBox()

                if e.isChoice {
                    VStack(spacing: 8) {
                        ForEach(e.options.indices, id: \.self) { i in
                            let state: (Color, Color, Color) = !checked ? (Ink.card, Ink.ink, Ink.ink) : i == e.answer ? (Ink.ink, Ink.onInk, Ink.ink) : i == picked ? (Ink.akane, Ink.onAkane, Ink.akane) : (Ink.card, Ink.soft, Ink.line)
                            Button { if !checked { picked = i; check(e) } } label: {
                                HStack {
                                    Text(["一", "二", "三", "四", "五"][min(i, 4)]).font(Typo.mincho(14)).foregroundStyle(checked ? state.1 : Ink.akane)
                                    Text(e.options[i]).font(Typo.mincho(20))
                                    Spacer()
                                    Kbd("\(i + 1)")
                                }
                                .padding(.horizontal, 16).frame(height: 50)
                                .foregroundStyle(state.1).background(state.0)
                                .overlay(Rectangle().strokeBorder(state.2, lineWidth: 2))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [])
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        TextField("Answer", text: $typed)
                            .textFieldStyle(.plain).font(Typo.mincho(24))
                            .padding(.horizontal, 14).frame(height: 54)
                            .inkBox(Ink.card, border: checked ? (right ? Ink.ink : Ink.akane) : Ink.ink)
                            .onSubmit { if !checked { check(e) } }
                            .disabled(checked)
                            .focused($fieldFocused)
                            .onChange(of: fieldFocused) { _, f in router.typing = f }
                            .onDisappear { router.typing = false }
                        Button("Check") { check(e) }.buttonStyle(InkButtonStyle(kind: .ink, height: 54)).frame(width: 110).disabled(checked || typed.isEmpty)
                    }
                }

                if checked {
                    VStack(alignment: .leading, spacing: 6) {
                        MixedText(right ? "正解! Correct" : "Not quite" + (e.isChoice ? "" : " · answer: \(e.accepted.first ?? "")"), size: 15, weight: .heavy, color: right ? Ink.ink : Ink.akane)
                        if !e.explainEN.isEmpty { MixedText(e.explainEN, size: 13) }
                        if !e.explainTH.isEmpty { MixedText(e.explainTH, size: 13, color: Ink.soft) }
                        Button { index += 1; reset() } label: { HStack { Text("Next"); Kbd("↩", light: true) } }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 42)).frame(width: 140)
                            .keyboardShortcut(.return, modifiers: [])
                    }
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                TrackedLabel(text: "This exercise practises", color: Ink.ink)
                Text(g.pattern).font(Typo.mincho(22))
                Text("\(g.th) · \(g.en)").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                MixedText(g.structure, size: 13, weight: .bold, color: Ink.onInk).padding(8).background(Ink.ink)
                Spacer()
            }
            .frame(width: 280)
        }
        .padding(30)
    }

    private func check(_ e: GrammarExercise) {
        checked = true
        if isRight(e) { score += 1; Haptic.success() } else { Haptic.warning() }
    }
}

struct QuizLauncher: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    var body: some View {
        Button("Start a 10-question quiz") {
            router.startQuiz("\(lesson.ja) · Practice", cards: lesson.allCards, count: 10, store: store)
        }
        .buttonStyle(InkButtonStyle(kind: .akane, height: 46)).frame(width: 260)
    }
}

// MARK: - Test

struct TestStepView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    @State private var mode = "book"

    var body: some View {
        VStack(spacing: 0) {
            if let tb = Textbook.lesson(lesson.n), !tb.quiz.isEmpty {
                HStack(spacing: 14) {
                    Segmented(options: [("book", "問題 แบบทดสอบท้ายบท"), ("cards", "試験 ทดสอบคำศัพท์·คันจิ")], selection: $mode, height: 34).frame(width: 440)
                    if let best = course.tests[lesson.n] { Text("คะแนนดีที่สุด \(best)%").font(Typo.ui(13, .heavy)).foregroundStyle(best >= 70 ? Ink.ink : Ink.akane) }
                    Spacer()
                }
                .padding(.horizontal, 30).padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                if mode == "book" {
                    TextbookQuizView(lesson: lesson, items: tb.quiz).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { cardTest }
            } else {
                cardTest
            }
            StepFooter(lesson: lesson, step: .test, canMarkDone: false)
        }
    }

    private var cardTest: some View {
        let best = course.tests[lesson.n]
        return VStack(spacing: 0) {
            HStack(spacing: 40) {
                ZStack {
                    FocusLines(count: 70).frame(width: 360, height: 360)
                        .mask(RadialGradient(colors: [.clear, .black, .black, .clear], center: .center, startRadius: 60, endRadius: 180))
                    Circle().fill(Ink.paper).frame(width: 170)
                    if course.passed(lesson.n) { StampBadge(text: "済", size: 120) } else {
                        Text("試").font(Typo.mincho(110)).foregroundStyle(Ink.ink)
                    }
                }
                .frame(width: 360, height: 360)
                VStack(alignment: .leading, spacing: 14) {
                    TrackedLabel(text: "試験 · Lesson test")
                    Text("\(lesson.ja) — test").font(Typo.mincho(32))
                    Text("15 JLPT-style questions on this lesson's words, kanji and grammar. Score 70% or more to stamp the lesson 済.")
                        .font(Typo.ui(14)).foregroundStyle(Ink.soft).frame(maxWidth: 420, alignment: .leading)
                    if let best { Text("Best score: \(best)%").font(Typo.ui(15, .heavy)).foregroundStyle(best >= 70 ? Ink.ink : Ink.akane) }
                    Button {
                        router.startQuiz("Lesson \(lesson.n) test", cards: lesson.allCards, count: 15, lessonTest: lesson.n, store: store)
                    } label: { Text(best == nil ? "Start the test →" : "Retake the test →").padding(.horizontal, 22) }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 52)).fixedSize()
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
