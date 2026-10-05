import SwiftUI

struct MacCourseView: View {
    @Environment(MacRouter.self) private var router
    var body: some View {
        if let n = router.lessonN, let lesson = Course.shared.lessons.first(where: { $0.n == n }) {
            MacLessonView(lesson: lesson).id(n)
        } else {
            CourseMapView()
        }
    }
}

// MARK: - Course map

struct CourseMapView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    @State private var selected: Int?
    @State private var level: Level?

    var body: some View {
        let shownLevel = level ?? store.settings.level
        let lessons = Course.shared.lessons(shownLevel)
        let current = course.currentLesson?.n ?? 0
        let sel = selected ?? (lessons.contains { $0.n == current } ? current : lessons.first?.n ?? 0)
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            TrackedLabel(text: "道 · Course")
                            Text("N5 → N4").font(Typo.mincho(30))
                        }
                        Spacer()
                        let passed = Course.shared.lessons.filter { course.passed($0.n) }.count
                        Text("\(passed) of \(Course.shared.lessons.count) 済").font(Typo.ui(13, .heavy))
                    }
                    Segmented(options: [(Level.n5, "N5 · lessons 0–14"), (.n4, "N4 · lessons 15–32")], selection: Binding(get: { shownLevel }, set: { level = $0; selected = nil }), height: 32, fill: true)
                }
                .padding(.horizontal, 24).padding(.top, 24)

                ScrollView {
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(Ink.ink).frame(width: 2).padding(.leading, 43).padding(.vertical, 20)
                        VStack(spacing: 2) {
                            ForEach(lessons) { l in lessonRow(l, selected: l.n == sel, current: l.n == current) }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 20)
                }
            }
            .frame(width: 420)
            .overlay(alignment: .trailing) { Rectangle().fill(Ink.ink).frame(width: 2) }

            if let l = lessons.first(where: { $0.n == sel }) {
                LessonOverview(lesson: l)
            }
        }
    }

    private func lessonRow(_ l: CourseLesson, selected: Bool, current: Bool) -> some View {
        let passed = course.passed(l.n)
        let started = course.doneCount(l.n) > 0
        return Button { self.selected = l.n } label: {
            HStack(spacing: 14) {
                Text(l.numeral).font(Typo.mincho(l.n >= 10 ? 13 : 18))
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(passed || current ? Ink.onInk : Ink.ink)
                    .background(passed ? Ink.ink : current ? Ink.akane : Ink.paper)
                    .overlay(Rectangle().strokeBorder(passed ? Ink.ink : current ? Ink.akane : Ink.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 0) {
                    MixedText(l.ja, size: 16, weight: .bold, color: current ? Ink.akane : Ink.ink)
                    Text("Lesson \(l.n) · \(l.en)").font(Typo.ui(11)).opacity(0.75).lineLimit(1)
                }
                Spacer()
                Text(passed ? "済" : current ? "NOW" : started ? "\(course.doneCount(l.n))/\(course.stepCount(l.n))" : "")
                    .font(passed ? Typo.mincho(14) : .system(size: 10, weight: .heavy))
                    .foregroundStyle(passed || current ? Ink.akane : Ink.soft)
            }
            .padding(.trailing, 10)
            .frame(minHeight: 46)
            .foregroundStyle(current ? Ink.akane : Ink.ink)
            .background(selected ? Ink.chip : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LessonOverview: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson

    var body: some View {
        let l = lesson
        let words = l.sections.reduce(0) { $0 + $1.ids.count }
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Ink.card
                HalftoneField(fade: .right, spacing: 6, maxRadius: 2).opacity(0.5)
                Text(l.ja.prefix(1)).font(Typo.mincho(300)).foregroundStyle(Ink.ink.opacity(0.07))
                    .frame(maxWidth: .infinity, alignment: .trailing).offset(x: -20, y: 90)
                VStack(alignment: .leading, spacing: 6) {
                    Text("LESSON \(l.n) · \(l.level.title)").font(.system(size: 11, weight: .heavy)).tracking(2)
                        .padding(.horizontal, 9).padding(.vertical, 3).background(Ink.ink).foregroundStyle(Ink.onInk)
                    MixedText(l.ja, size: 42, weight: .bold)
                    (Text(l.en).font(Typo.ui(17, .medium)) + Text("  ·  \(l.th)").font(Typo.ui(15)).foregroundColor(Ink.soft))
                    Text(status).font(Typo.ui(13, .bold)).foregroundStyle(Ink.soft)
                }
                .padding(32)
            }
            .frame(height: 240)
            .clipped()
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }

            HStack(alignment: .top, spacing: 30) {
                ScrollView { VStack(alignment: .leading, spacing: 8) {
                    if !l.isKana, let tb = Textbook.lesson(l.n) {
                        NumberedRule(numeral: "目", title: "Goals · เป้าหมาย")
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(tb.goalsTH, id: \.self) { g in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("□").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
                                    MixedText(g, size: 14)
                                }
                            }
                            Text("📺 วิดีโอ \(tb.video.count) ตอน · \(tb.beatCount) ฉาก  ·  文法 \(tb.grammar.count) หัวข้อ  ·  แบบฝึก \(tb.drillA.count + tb.drillB.count + tb.drillC.count) ชุด  ·  ข้อสอบ \(tb.quiz.count) ข้อ")
                                .font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft).padding(.top, 4)
                        }
                        .padding(.bottom, 12)
                    }
                    NumberedRule(numeral: "学", title: l.isKana ? "Kana" : "Grammar in this lesson")
                    if l.isKana {
                        Text("The hiragana and katakana charts with audio, dakuten and yōon, then recognition drills. Everything later builds on these.")
                            .font(Typo.ui(14)).foregroundStyle(Ink.soft)
                    }
                        VStack(spacing: 0) {
                            ForEach(Array(l.grammarCards.enumerated()), id: \.offset) { i, c in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(String(format: "%02d", i + 1)).font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane)
                                    VStack(alignment: .leading, spacing: 2) {
                                        MixedText(c.prompt, size: 17, weight: .bold)
                                        Text("\(c.meaning) · \(c.meaningEN)").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                                    }
                                    Spacer()
                                    if course.points.contains(c.grammarItem!.key) { Text("✓").foregroundStyle(Ink.akane) }
                                }
                                .padding(.vertical, 9)
                                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                            }
                        }
                } }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    NumberedRule(numeral: "中", title: "What's inside")
                    HStack(spacing: 0) {
                        stat(l.isKana ? "\(KanaData.all.count)" : "\(words)", l.isKana ? "kana" : "words")
                        Rectangle().fill(Ink.ink).frame(width: 2)
                        stat("\(l.grammar.count)", "grammar")
                        Rectangle().fill(Ink.ink).frame(width: 2)
                        stat("\(l.kanji.count)", "kanji")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .inkBox()
                    if !l.kanji.isEmpty {
                        Flow(spacing: 6) {
                            ForEach(l.kanji, id: \.self) { k in
                                Text(k).font(Typo.mincho(19)).frame(width: 34, height: 34)
                                    .foregroundStyle(store.mastery("k:" + k) >= .young ? Ink.onInk : Ink.ink)
                                    .background(store.mastery("k:" + k) >= .young ? Ink.ink : Ink.card)
                                    .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                            }
                        }
                    }
                    VStack(spacing: 6) {
                        ForEach(l.dialogues, id: \.self) { key in
                            if let d = Course.shared.dialogue(key) { extra("話", d.jaTitle, "CONVERSATION") }
                        }
                        ForEach(l.stories, id: \.self) { key in
                            if let s = Course.shared.story(key) { extra("読", s.jaTitle, "STORY") }
                        }
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Button { router.openLesson(l.n, step: course.nextStep(l.n)) } label: {
                            Text(course.passed(l.n) ? "Review lesson →" : course.doneCount(l.n) > 0 ? "Continue lesson →" : "Start lesson →")
                        }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 50))
                        .keyboardShortcut(.return, modifiers: [])
                        Button { router.openLesson(l.n, step: .test) } label: { Text("試 Test out").padding(.horizontal, 14) }
                            .buttonStyle(InkButtonStyle(kind: .outline, height: 50)).fixedSize()
                    }
                }
                .frame(width: 330)
            }
            .padding(32)
        }
    }

    private var status: String {
        if course.passed(lesson.n) { return "済 Completed · test \(course.tests[lesson.n] ?? 0)%" }
        let d = course.doneCount(lesson.n)
        return d > 0 ? "In progress · \(d) of \(course.stepCount(lesson.n)) steps done" : "Not started · open any step"
    }

    private func stat(_ big: String, _ small: String) -> some View {
        VStack(spacing: 2) {
            Text(big).font(Typo.mincho(26))
            Text(small).font(Typo.ui(11, .bold)).foregroundStyle(Ink.soft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
    }

    private func extra(_ glyph: String, _ title: String, _ kind: String) -> some View {
        HStack(spacing: 10) {
            Text(glyph).font(Typo.mincho(16)).foregroundStyle(Ink.akane)
            Text(title).font(Typo.mincho(15))
            Spacer()
            Text(kind).font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(Ink.soft)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .inkBox(width: 1.5)
    }
}
