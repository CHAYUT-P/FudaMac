import SwiftUI

// The textbook lesson flow: 文型 patterns & examples → 動画 video → 文法 notes →
// (会話 conversation in TalkStepView) → 練習 drills A/B/C → 問題 lesson check.
// Content comes from Resources/textbook-LNN.json (see Tools/textbook/SCHEMA.md).

// MARK: - Shared bits

private struct BookHeading: View {
    let ja: String
    let th: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(ja).font(Typo.mincho(22)).foregroundStyle(Ink.ink)
            Text(th).font(Typo.ui(14, .bold)).foregroundStyle(Ink.soft)
            Rectangle().fill(Ink.ink).frame(height: 2).frame(maxWidth: .infinity).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 6 }
        }
        .padding(.top, 8)
    }
}

/// Play several Japanese lines one after another.
enum SpeakQueue {
    nonisolated(unsafe) private static var generation = 0

    /// Starts a new queue (cancelling any running one).
    static func play(_ lines: [String], voices: [Speech.Voice]? = nil, onLine: ((Int?) -> Void)? = nil) {
        generation += 1
        step(lines, voices: voices, from: 0, gen: generation, onLine: onLine)
    }

    /// Stops the queue and the voice; nothing queued plays later.
    static func stop() {
        generation += 1
        Speech.shared.stop()
    }

    private static func step(_ lines: [String], voices: [Speech.Voice]?, from i: Int, gen: Int, onLine: ((Int?) -> Void)?) {
        guard gen == generation else { return }
        guard i < lines.count else { onLine?(nil); return }
        onLine?(i)
        Speech.shared.say(lines[i], voice: voices.flatMap { $0.indices.contains(i) ? $0[i] : nil } ?? .main) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { step(lines, voices: voices, from: i + 1, gen: gen, onLine: onLine) }
        }
    }
}

// MARK: - 文型 Patterns & examples

struct TextbookBookView: View {
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    let tb: TextbookLesson

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                HStack(alignment: .top, spacing: 34) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            TrackedLabel(text: "第\(lesson.numeral)課 · Lesson \(lesson.n) · 第\(lesson.part.numeral)部 \(lesson.part.ja)")
                            MixedText(tb.titleJA, size: 36, weight: .bold)
                            Text(tb.titleTH).font(Typo.ui(17, .semibold)).foregroundStyle(Ink.soft)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            TrackedLabel(text: "目標 · จบบทนี้แล้วคุณจะ…", color: Ink.ink)
                            ForEach(tb.goalsTH, id: \.self) { g in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("□").font(Typo.ui(15, .heavy)).foregroundStyle(Ink.akane)
                                    MixedText(g, size: 15)
                                }
                            }
                        }
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading).inkBox(Ink.card)

                        BookHeading(ja: "文型", th: "รูปประโยคหลักของบทนี้")
                        ForEach(Array(tb.patterns.enumerated()), id: \.offset) { i, p in
                            HStack(alignment: .top, spacing: 16) {
                                Text("\(i + 1)").font(Typo.mincho(30)).foregroundStyle(Ink.akane).frame(width: 30)
                                VStack(alignment: .leading, spacing: 8) {
                                    JPText(ja: p.ja, kana: p.kana, size: 30, bold: true)
                                    Text(p.th).font(Typo.ui(15, .semibold))
                                    if let n = p.noteTH, !n.isEmpty {
                                        MixedText(n, size: 13, color: Ink.soft)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Ink.chip)
                                    }
                                }
                                Spacer(minLength: 0)
                                SpeakIcon(text: p.kana, size: 34)
                            }
                            .padding(18).inkBox()
                        }

                        BookHeading(ja: "例文", th: "ตัวอย่างถาม–ตอบ (กด ▶ ฟังทั้งคู่)")
                        ForEach(Array(tb.examples.enumerated()), id: \.offset) { i, e in
                            HStack(alignment: .top, spacing: 14) {
                                Text(String(format: "%02d", i + 1)).font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane).frame(width: 24)
                                VStack(alignment: .leading, spacing: 10) {
                                    qa("Q", e.q)
                                    qa("A", e.a)
                                }
                                Spacer(minLength: 0)
                                Button { SpeakQueue.play([e.q.kana, e.a.kana], voices: [.partner, .main]) } label: {
                                    Image(systemName: "play.fill").font(.system(size: 12)).foregroundStyle(Ink.onAkane)
                                        .frame(width: 32, height: 32).background(Circle().fill(Ink.akane))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14).inkBox()
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        TrackedLabel(text: "วิธีเรียนบทนี้", color: Ink.ink)
                        ForEach(Array(LessonStep.steps(for: lesson.n).enumerated()), id: \.offset) { i, st in
                            Button { router.step = st } label: {
                                HStack(spacing: 10) {
                                    Text("\(i + 1)").font(Typo.ui(11, .heavy)).frame(width: 20, height: 20)
                                        .foregroundStyle(Ink.onInk).background(st == .learn ? Ink.akane : Ink.ink)
                                    Text(st.ja(lesson.n)).font(Typo.mincho(15))
                                    Text(Self.stepTH[st] ?? "").font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        Text("อ่านรูปประโยคและตัวอย่างให้คุ้นก่อน แล้วดูวิดีโอ ถ้ายังงง อ่านคำอธิบายละเอียดในส่วน 文法")
                            .font(Typo.ui(12)).foregroundStyle(Ink.soft).fixedSize(horizontal: false, vertical: true)
                        Button { router.step = .video } label: { HStack { Image(systemName: "play.fill"); Text("ดูวิดีโอบทเรียน") } }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 46))
                    }
                    .frame(width: 250)
                }
                .padding(30)
            }
            StepFooter(lesson: lesson, step: .learn)
        }
        .onDisappear { SpeakQueue.stop() }
    }

    static let stepTH: [LessonStep: String] = [
        .learn: "รูปประโยค + ตัวอย่าง", .video: "วิดีโออธิบายทีละขั้น", .notes: "คำอธิบายไวยากรณ์ละเอียด",
        .talk: "บทสนทนา + เล่นบทบาท", .words: "คำศัพท์ของบท", .kanji: "คันจิของบท",
        .practice: "แบบฝึก A · B · C", .read: "อ่านเรื่องสั้น", .test: "แบบทดสอบท้ายบท"
    ]

    private func qa(_ tag: String, _ t: TBText) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(tag).font(Typo.ui(11, .heavy)).frame(width: 20, height: 20)
                .foregroundStyle(tag == "Q" ? Ink.ink : Ink.onInk)
                .background(tag == "Q" ? Ink.chip : Ink.ink)
            SentenceBlock(ja: t.ja, kana: t.kana, th: t.th ?? "", en: t.en ?? "", size: 21)
        }
    }
}

// MARK: - 動画 Video

struct TextbookVideoView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    let tb: TextbookLesson

    var body: some View {
        let v = tb.playerBeats
        VStack(spacing: 0) {
            if v.beats.isEmpty {
                Text("No video for this lesson yet").font(Typo.ui(16, .heavy)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LessonPlayer(title: "第\(lesson.numeral)課", beats: v.beats, start: router.debugBeat, chapters: v.chapters, video: true) {
                    course.complete(lesson.n, .video)
                    router.step = .notes
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .id("video-\(lesson.n)-\(router.debugBeat)")
            }
            StepFooter(lesson: lesson, step: .video)
        }
    }
}

// MARK: - 文法 Grammar notes

struct TextbookNotesView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    let tb: TextbookLesson
    @State private var interactive = false
    @State private var current = 0

    var body: some View {
        VStack(spacing: 0) {
            if !lesson.grammarCards.isEmpty {
                HStack {
                    Segmented(options: [(false, "解説 คำอธิบาย"), (true, "◇ อินโฟกราฟิก · ฝึกโต้ตอบ")], selection: $interactive, height: 32)
                        .frame(width: 420)
                    Spacer()
                }
                .padding(.horizontal, 30).padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
            }
            if interactive {
                LearnStepView(lesson: lesson, showFooter: false, step: .notes, nextStep: .talk)
            } else {
                notes
            }
            StepFooter(lesson: lesson, step: .notes)
        }
    }

    private var notes: some View {
        ScrollViewReader { proxy in
            HStack(alignment: .top, spacing: 0) {
                ScrollView { VStack(alignment: .leading, spacing: 2) {
                    TrackedLabel(text: "文法 · \(tb.grammar.count) หัวข้อ").padding(.bottom, 8)
                    ForEach(Array(tb.grammar.enumerated()), id: \.offset) { i, g in
                        Button {
                            current = i
                            withAnimation { proxy.scrollTo("g\(i)", anchor: .top) }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text(String(format: "%02d", i + 1)).font(Typo.ui(11, .heavy)).foregroundStyle(i == current ? Ink.akane : Ink.soft)
                                VStack(alignment: .leading, spacing: 1) {
                                    MixedText(g.titleJA, size: 14, weight: .bold)
                                    Text(g.titleTH).font(Typo.ui(11)).foregroundStyle(Ink.soft).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(i == current ? Ink.card : .clear)
                            .overlay(alignment: .leading) { Rectangle().fill(i == current ? Ink.akane : .clear).frame(width: 3) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } }
                .frame(width: 250).padding(.vertical, 20).padding(.leading, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 34) {
                        ForEach(Array(tb.grammar.enumerated()), id: \.offset) { i, g in
                            GrammarSectionView(number: i + 1, g: g).id("g\(i)")
                        }
                        HStack(spacing: 14) {
                            StampBadge(text: course.isDone(lesson.n, .notes) ? "済" : "読")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("อ่านครบทุกหัวข้อแล้ว?").font(Typo.ui(16, .heavy))
                                Text("ต่อไปฟังบทสนทนาของบทนี้ แล้วลองเล่นบทบาทเป็นตัม").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                            }
                            Spacer()
                            Button {
                                course.complete(lesson.n, .notes)
                                for g in tb.grammar { for k in g.allKeys { course.markPoint(k) } }
                                router.step = .talk
                            } label: { Text("อ่านจบแล้ว → 会話").padding(.horizontal, 16) }
                                .buttonStyle(InkButtonStyle(kind: .akane, height: 44)).fixedSize()
                        }
                        .padding(18).inkBox(Ink.card)
                    }
                    .frame(maxWidth: 880, alignment: .leading)
                    .padding(30)
                }
            }
            .onAppear {
                // Opened from search: jump to that section.
                guard let target = router.notesSection, tb.grammar.indices.contains(target) else { return }
                router.notesSection = nil
                current = target
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { proxy.scrollTo("g\(target)", anchor: .top) }
            }
        }
    }
}

struct GrammarSectionView: View {
    let number: Int
    let g: TBGrammar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Text("\(number)").font(Typo.mincho(26)).foregroundStyle(Ink.onAkane).frame(width: 46, height: 46).background(Ink.akane)
                VStack(alignment: .leading, spacing: 2) {
                    MixedText(g.titleJA, size: 26, weight: .bold)
                    MixedText(g.titleTH, size: 15, weight: .semibold, color: Ink.soft)
                }
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2).offset(y: 8) }
            ForEach(Array(g.blocks.enumerated()), id: \.offset) { _, b in block(b) }
            GrammarInConversation(keys: g.allKeys, pattern: g.titleJA)
        }
    }

    @ViewBuilder private func block(_ b: TBBlock) -> some View {
        switch b.t {
        case "p":
            MixedText(b.th ?? "", size: 15.5)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        case "ex":
            if let ja = b.ja, let kana = b.kana {
                HStack(alignment: .top, spacing: 12) {
                    Text("例").font(Typo.mincho(15)).foregroundStyle(Ink.akane)
                    SentenceBlock(ja: ja, kana: kana, th: b.th ?? "", en: "", size: 22)
                    Spacer(minLength: 0)
                    SpeakIcon(text: kana, size: 28)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Ink.card)
                .overlay(alignment: .leading) { Rectangle().fill(Ink.akane).frame(width: 4) }
            }
        case "table":
            table(b.rows ?? [])
        case "tip":
            HStack(alignment: .top, spacing: 12) {
                Text("ヒント").font(.system(size: 11, weight: .heavy)).tracking(1).foregroundStyle(Ink.onInk)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(Ink.ink)
                MixedText(b.th ?? "", size: 14.5).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14).background(Ink.chip)
        case "warn":
            HStack(alignment: .top, spacing: 12) {
                Text("注意").font(.system(size: 11, weight: .heavy)).tracking(1).foregroundStyle(Ink.onAkane)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(Ink.akane)
                MixedText(b.th ?? "", size: 14.5).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .overlay(Rectangle().strokeBorder(Ink.akane, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
        case "compare":
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("比較").font(.system(size: 11, weight: .heavy)).tracking(1).foregroundStyle(Ink.onInk)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(Ink.ink)
                    MixedText(b.th ?? "", size: 14, weight: .semibold).fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: 0) {
                    side(b.left, tag: "A")
                    Rectangle().fill(Ink.ink).frame(width: 2)
                    side(b.right, tag: "B")
                }
                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder private func side(_ t: TBText?, tag: String) -> some View {
        if let t {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tag).font(Typo.ui(11, .heavy)).foregroundStyle(Ink.akane)
                    Spacer()
                    SpeakIcon(text: t.kana, size: 24)
                }
                SentenceBlock(ja: t.ja, kana: t.kana, th: t.th ?? "", en: "", size: 20)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Ink.card)
        }
    }

    private func table(_ rows: [[String]]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { c, cell in
                        let head = r == 0
                        MixedText(cell, size: head ? 13 : 16, weight: head || c == 0 ? .bold : .regular, color: head ? Ink.onInk : Ink.ink)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .background(head ? Ink.ink : c == 0 ? Ink.chip : Ink.card)
                            .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 0.5))
                    }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
    }
}

// MARK: - 練習 Drills A · B · C

struct TextbookDrillsView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    let tb: TextbookLesson

    var body: some View {
        @Bindable var router = router
        let tab = tabs.contains { $0.0 == router.drillTab } ? router.drillTab : "A"
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Segmented(options: tabs, selection: $router.drillTab, height: 34).frame(width: CGFloat(tabs.count) * 150)
                Text(Self.help[tab] ?? "").font(Typo.ui(13)).foregroundStyle(Ink.soft).lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 30).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
            Group {
                switch tab {
                case "A": DrillAView(drills: tb.drillA)
                case "B": DrillBView(drills: tb.drillB.filter { !$0.items.isEmpty }) { course.complete(lesson.n, .practice) }
                case "C": DrillCView(drills: tb.drillC)
                default: PracticeStepView(lesson: lesson, showFooter: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            StepFooter(lesson: lesson, step: .practice)
        }
    }

    private var tabs: [(String, String)] {
        var t: [(String, String)] = [("A", "練習A แทนที่"), ("B", "練習B แปลงประโยค"), ("C", "練習C สนทนา")]
        if lesson.grammarCards.contains(where: { !($0.grammarItem?.exercises.isEmpty ?? true) }) { t.append(("X", "＋ แบบฝึกเพิ่ม")) }
        return t
    }

    static let help: [String: String] = [
        "A": "ฟังและอ่านออกเสียงตามทีละแถว สังเกตส่วนสีแดงที่เปลี่ยนไป",
        "B": "ดูตัวอย่างแล้วพิมพ์ประโยคใหม่ (พิมพ์คานะ คันจิ หรือโรมาจิก็ได้)",
        "C": "บทสนทนาสั้นๆ เปลี่ยนคำในช่องสีแดงได้ 3 แบบ ลองพูดตาม",
        "X": "แบบฝึกเพิ่มเติมจากคลังไวยากรณ์"
    ]
}

struct DrillAView: View {
    @Environment(ProgressStore.self) private var store
    let drills: [TBDrillA]
    @State private var hideTH = false
    @State private var playing: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    TrackedLabel(text: "練習A · ตารางแทนที่ \(drills.count) ชุด")
                    Spacer()
                    Toggle("ซ่อนคำแปล (ทดสอบตัวเอง)", isOn: $hideTH).toggleStyle(.checkbox).font(Typo.ui(12, .bold))
                }
                ForEach(Array(drills.enumerated()), id: \.offset) { d, drill in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(d + 1)").font(Typo.mincho(22)).foregroundStyle(Ink.akane)
                            MixedText(drill.titleTH, size: 16, weight: .heavy)
                            Spacer()
                            Button {
                                SpeakQueue.play(drill.rows.map(\.kana)) { i in playing = i.map { "\(d)-\($0)" } }
                            } label: { HStack { Image(systemName: "play.fill"); Text("ฟังทั้งชุด") } }
                                .buttonStyle(InkButtonStyle(kind: .outline, height: 34)).fixedSize()
                        }
                        MixedText(drill.frame, size: 26, weight: .bold)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Ink.chip)
                            .overlay(Rectangle().strokeBorder(Ink.ink, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                        VStack(spacing: 0) {
                            ForEach(Array(drill.rows.enumerated()), id: \.offset) { i, r in
                                HStack(alignment: .center, spacing: 14) {
                                    Text("\(i + 1)").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.soft).frame(width: 18)
                                    VStack(alignment: .leading, spacing: 3) {
                                        JPText(ja: r.ja, kana: r.kana, size: 22, highlights: r.slots ?? [])
                                        Text(r.th).font(Typo.ui(13)).opacity(hideTH ? 0 : 1)
                                    }
                                    Spacer(minLength: 0)
                                    SpeakIcon(text: r.kana, size: 28)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(playing == "\(d)-\(i)" ? Ink.akane.opacity(0.1) : Ink.card)
                                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                            }
                        }
                        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(30)
        }
        .onDisappear { SpeakQueue.stop(); playing = nil }
    }
}

struct DrillBView: View {
    @Environment(MacRouter.self) private var router
    let drills: [TBDrillB]
    var onComplete: () -> Void
    @State private var set = 0
    @State private var item = 1          // item 0 is the worked example
    @State private var typed = ""
    @State private var checked = false
    @State private var revealed = false
    @State private var score = 0
    @State private var done = false
    @FocusState private var focused: Bool

    var body: some View {
        if drills.isEmpty {
            Text("ไม่มีแบบฝึก B ในบทนี้").font(Typo.ui(15, .heavy)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if done {
            VStack(spacing: 14) {
                StampBadge(text: "済", size: 90)
                Text("ทำแบบฝึก B ครบแล้ว · ถูก \(score) ข้อ").font(Typo.ui(18, .heavy))
                Button("ทำใหม่อีกครั้ง") { set = 0; item = 1; score = 0; done = false; reset() }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 42)).frame(width: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let d = drills[set]
            let it = d.items[min(item, d.items.count - 1)]
            let answers = [it.answer.ja, it.answer.kana] + (it.accept ?? [])
            let right = checked && isRight(it, answers)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        TrackedLabel(text: "練習B · ชุด \(set + 1) / \(drills.count) · ข้อ \(item) / \(max(1, d.items.count - 1))")
                        Spacer()
                        Text("ถูก \(score)").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
                    }
                    MixedText(d.instructionTH, size: 18, weight: .heavy)
                    if let ex = d.items.first {
                        HStack(alignment: .center, spacing: 14) {
                            Text("例").font(Typo.mincho(16)).foregroundStyle(Ink.onInk).frame(width: 30, height: 30).background(Ink.ink)
                            JPText(ja: ex.prompt.ja, kana: ex.prompt.kana, size: 18)
                            Text("→").font(Typo.ui(16, .heavy)).foregroundStyle(Ink.akane)
                            JPText(ja: ex.answer.ja, kana: ex.answer.kana, size: 18, bold: true)
                            Spacer(minLength: 0)
                            SpeakIcon(text: ex.answer.kana, size: 26)
                        }
                        .padding(12).background(Ink.chip)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        JPText(ja: it.prompt.ja, kana: it.prompt.kana, size: 32, bold: true)
                        if let th = it.prompt.th { Text(th).font(Typo.ui(14)).foregroundStyle(Ink.soft) }
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading).inkBox()
                    .overlay(alignment: .topTrailing) { SpeakIcon(text: it.prompt.kana, size: 28).padding(10) }

                    HStack(spacing: 10) {
                        TextField("พิมพ์คำตอบ…", text: $typed)
                            .textFieldStyle(.plain).font(Typo.mincho(24))
                            .padding(.horizontal, 14).frame(height: 54)
                            .inkBox(Ink.card, border: checked ? (right ? Ink.ink : Ink.akane) : Ink.ink)
                            .focused($focused)
                            .onChange(of: focused) { _, f in router.typing = f }
                            .onSubmit { if checked { advance() } else if !typed.isEmpty { check(it, answers) } }
                            .disabled(checked)
                        Button("ตรวจ") { check(it, answers) }.buttonStyle(InkButtonStyle(kind: .ink, height: 54)).frame(width: 100).disabled(checked || typed.isEmpty)
                        Button("เฉลย") { revealed = true; checked = true; Speech.shared.say(it.answer.kana) }
                            .buttonStyle(InkButtonStyle(kind: .outline, height: 54)).frame(width: 90).disabled(checked)
                    }
                    if checked {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(right ? "正解! ถูกต้อง" : revealed ? "คำตอบคือ" : "ยังไม่ถูก — คำตอบคือ").font(Typo.ui(15, .heavy)).foregroundStyle(right ? Ink.ink : Ink.akane)
                            HStack {
                                JPText(ja: it.answer.ja, kana: it.answer.kana, size: 26, bold: true)
                                SpeakIcon(text: it.answer.kana, size: 28)
                            }
                            Button { advance() } label: { HStack { Text("ข้อต่อไป"); Kbd("↩", light: true) } }
                                .buttonStyle(InkButtonStyle(kind: .akane, height: 42)).frame(width: 160)
                                .keyboardShortcut(.return, modifiers: [])
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).inkBox(Ink.card, border: right ? Ink.ink : Ink.akane)
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(30)
            }
            .onAppear { focused = true }
            .onDisappear { router.typing = false }
        }
    }

    private func isRight(_ it: TBDrillBItem, _ answers: [String]) -> Bool {
        if revealed { return false }
        if AnswerCheck.matches(typed, answers) { return true }
        let heard = AnswerCheck.reading(typed)
        if !heard.isEmpty, ([it.answer.kana] + (it.accept ?? [])).contains(where: { AnswerCheck.reading($0) == heard }) { return true }
        // Romaji typing: compare against the answer's romaji.
        let latin = typed.lowercased().filter { $0.isLetter }
        guard !latin.isEmpty, latin.allSatisfy({ $0.isASCII }) else { return false }
        let forms = [Furigana.romaji(it.answer.ja, it.answer.kana), Romaji.from(it.answer.kana)].map { $0.lowercased().filter { $0.isLetter } }
        return forms.contains(latin)
    }

    private func check(_ it: TBDrillBItem, _ answers: [String]) {
        checked = true
        if isRight(it, answers) { score += 1; Haptic.success() } else { Haptic.warning() }
        Speech.shared.say(it.answer.kana)
    }

    private func reset() { typed = ""; checked = false; revealed = false; focused = true }

    private func advance() {
        let d = drills[set]
        if item < d.items.count - 1 { item += 1 }
        else if set < drills.count - 1 { set += 1; item = min(1, drills[set].items.count - 1) }
        else { done = true; onComplete() }
        reset()
    }
}

struct DrillCView: View {
    let drills: [TBDrillC]
    @State private var variant: [Int: Int] = [:]
    @State private var playing: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                TrackedLabel(text: "練習C · บทสนทนาสั้น \(drills.count) ชุด")
                ForEach(Array(drills.enumerated()), id: \.offset) { d, drill in
                    let v = variant[d] ?? 0
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(d + 1)").font(Typo.mincho(22)).foregroundStyle(Ink.akane)
                            MixedText(drill.situationTH, size: 16, weight: .heavy)
                            Spacer()
                        }
                        HStack(alignment: .top, spacing: 10) {
                            Flow(spacing: 8) {
                                Text("เปลี่ยนคำ:").font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft).frame(height: 30)
                                ForEach(0..<drill.variants, id: \.self) { i in
                                    Button { variant[d] = i } label: {
                                        HStack(spacing: 6) {
                                            Text("\(i + 1)").font(Typo.ui(11, .heavy)).foregroundStyle(i == v ? Ink.onAkane : Ink.akane)
                                            Text(drill.choices.map { $0[i].ja }.joined(separator: " / ")).font(Typo.mincho(14)).lineLimit(1)
                                                .foregroundStyle(i == v ? Ink.onInk : Ink.ink)
                                        }
                                        .padding(.horizontal, 10).frame(maxWidth: 300, minHeight: 30)
                                        .background(i == v ? Ink.ink : .clear)
                                        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Spacer(minLength: 0)
                            Button {
                                let lines = drill.lines.map { drill.fill($0.kana, variant: v, key: \.kana) }
                                let speakers = drill.lines.map(\.speaker)
                                SpeakQueue.play(lines, voices: speakers.map { $0 == speakers.first ? .partner : .main }) { i in playing = i.map { "\(d)-\($0)" } }
                            } label: { HStack { Image(systemName: "play.fill"); Text("ฟัง") }.padding(.horizontal, 12) }
                                .buttonStyle(InkButtonStyle(kind: .outline, height: 32)).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(drill.lines.enumerated()), id: \.offset) { i, line in
                                let slots = drill.choices.map { $0.indices.contains(v) ? $0[v].ja : "" }
                                HStack(alignment: .top, spacing: 12) {
                                    Text(line.speaker).font(.system(size: 12, weight: .heavy)).frame(width: 34, height: 26)
                                        .foregroundStyle(i % 2 == 0 ? Ink.ink : Ink.onAkane).background(i % 2 == 0 ? Ink.chip : Ink.akane)
                                    VStack(alignment: .leading, spacing: 3) {
                                        JPText(ja: drill.fill(line.ja, variant: v, key: \.ja), kana: drill.fill(line.kana, variant: v, key: \.kana), size: 21, highlights: slots)
                                        Text(drill.fillTH(line.th, variant: v)).font(Typo.ui(13))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .background(playing == "\(d)-\(i)" ? Ink.akane.opacity(0.1) : Ink.card)
                            }
                        }
                        .padding(8).inkBox(Ink.paper)
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(30)
        }
        .onDisappear { SpeakQueue.stop(); playing = nil }
    }
}

// MARK: - 問題 Lesson check

struct TextbookQuizView: View {
    @Environment(CourseProgress.self) private var course
    let lesson: CourseLesson
    let items: [TBQuiz]
    @State private var index = 0
    @State private var picked: Int?
    @State private var placed: [Int] = []       // order questions: indices into tiles
    @State private var bank: [Int] = []
    @State private var checked = false
    @State private var score = 0
    @State private var finished = false

    var body: some View {
        if items.isEmpty {
            Text("ไม่มีแบบทดสอบ").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if finished {
            let pct = Int((Double(score) / Double(items.count) * 100).rounded())
            VStack(spacing: 14) {
                StampBadge(text: pct >= 70 ? "済" : "再", size: 100)
                Text("\(score) / \(items.count) · \(pct)%").font(Typo.mincho(34))
                Text(pct >= 70 ? "ผ่านแล้ว! บทนี้ประทับตรา 済" : "ต้องได้ 70% ขึ้นไป ลองทบทวนส่วน 文法 แล้วทำใหม่").font(Typo.ui(15)).foregroundStyle(Ink.soft)
                Button("ทำใหม่อีกครั้ง") { index = 0; score = 0; finished = false; reset() }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 42)).frame(width: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { course.recordTest(lesson.n, score: pct) }
        } else {
            question(items[index])
                .id(index)
        }
    }

    private func reset() { picked = nil; placed = []; checked = false }   // the new question's onAppear prepares it

    private func prepare() {
        guard items.indices.contains(index) else { return }
        let q = items[index]
        if q.type == "order", let t = q.tiles {
            var b = Array(t.indices).shuffled()
            if b == Array(t.indices), b.count > 1 { b.swapAt(0, 1) }
            bank = b
        }
        if q.type == "listen", let k = q.kana { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Speech.shared.say(k) } }
    }

    private func isRight(_ q: TBQuiz) -> Bool {
        if q.type == "order" { return placed == Array((q.tiles ?? []).indices) || placed.map { q.tiles![$0] }.joined() == (q.tiles ?? []).joined() }
        return picked == q.answer
    }

    private func check(_ q: TBQuiz) {
        guard !checked else { return }
        checked = true
        if isRight(q) { score += 1; Haptic.success() } else { Haptic.warning() }
        if q.type == "order", let k = q.kana { Speech.shared.say(k) }
    }

    private func next() {
        if index < items.count - 1 { index += 1; reset() } else { finished = true }
    }

    private func question(_ q: TBQuiz) -> some View {
        let right = checked && isRight(q)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    TrackedLabel(text: "問題 · ข้อ \(index + 1) / \(items.count)")
                    Spacer()
                    Text("ถูก \(score)").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
                }
                HStack(spacing: 3) {
                    ForEach(0..<items.count, id: \.self) { i in Rectangle().fill(i < index ? Ink.ink : i == index ? Ink.akane : Ink.line).frame(height: 5) }
                }
                VStack(alignment: .leading, spacing: 12) {
                    MixedText(q.questionTH, size: 17, weight: .heavy)
                    if q.type == "listen" {
                        Button { if let k = q.kana { Speech.shared.say(k) } } label: {
                            HStack(spacing: 10) { Image(systemName: "speaker.wave.2.fill"); Text("ฟังอีกครั้ง") }
                                .font(Typo.ui(15, .heavy)).foregroundStyle(Ink.onAkane)
                                .padding(.horizontal, 18).frame(height: 48).background(Ink.akane)
                        }
                        .buttonStyle(.plain).keyboardShortcut("p", modifiers: [])
                        if checked, let k = q.kana { Text(k).font(Typo.mincho(22)) }
                    } else if let ja = q.ja {
                        JPText(ja: ja, kana: q.kana ?? "", size: 30, bold: true)
                    }
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading).inkBox()

                if q.type == "order" { order(q) } else { choices(q) }

                if checked {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(right ? "正解! ถูกต้อง" : "ยังไม่ถูก").font(Typo.ui(16, .heavy)).foregroundStyle(right ? Ink.ink : Ink.akane)
                        if q.type == "order", let t = q.tiles, let k = q.kana {
                            JPText(ja: t.joined(), kana: k, size: 22, bold: true)
                        }
                        if let e = q.explainTH, !e.isEmpty { MixedText(e, size: 14).fixedSize(horizontal: false, vertical: true) }
                        Button { next() } label: { HStack { Text(index == items.count - 1 ? "ดูผล" : "ข้อต่อไป"); Kbd("↩", light: true) } }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 42)).frame(width: 160)
                            .keyboardShortcut(.return, modifiers: [])
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).inkBox(Ink.card, border: right ? Ink.ink : Ink.akane)
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(30)
        }
        .onAppear(perform: prepare)
    }

    private func choices(_ q: TBQuiz) -> some View {
        VStack(spacing: 8) {
            ForEach(Array((q.options ?? []).enumerated()), id: \.offset) { i, opt in
                let state: (Color, Color, Color) = !checked ? (Ink.card, Ink.ink, Ink.ink) : i == q.answer ? (Ink.ink, Ink.onInk, Ink.ink) : i == picked ? (Ink.akane, Ink.onAkane, Ink.akane) : (Ink.card, Ink.soft, Ink.line)
                Button { if !checked { picked = i; check(q) } } label: {
                    HStack(spacing: 12) {
                        Text(["一", "二", "三", "四", "五"][min(i, 4)]).font(Typo.mincho(14)).foregroundStyle(checked ? state.1 : Ink.akane)
                        MixedText(opt, size: 19, weight: .semibold, color: state.1)
                        Spacer()
                        Kbd("\(i + 1)")
                    }
                    .padding(.horizontal, 16).frame(minHeight: 52)
                    .background(state.0)
                    .overlay(Rectangle().strokeBorder(state.2, lineWidth: 2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(i < 9 ? KeyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: []) : nil)
            }
        }
    }

    private func order(_ q: TBQuiz) -> some View {
        let tiles = q.tiles ?? []
        return VStack(alignment: .leading, spacing: 14) {
            // Answer line
            Flow(spacing: 8) {
                ForEach(placed, id: \.self) { i in
                    Button { if !checked { placed.removeAll { $0 == i }; bank.append(i) } } label: { tile(tiles[i], on: true) }.buttonStyle(.plain)
                }
                if placed.isEmpty { Text("แตะคำด้านล่างเพื่อเรียงประโยค").font(Typo.ui(13)).foregroundStyle(Ink.soft).frame(height: 44) }
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }
            // Bank
            Flow(spacing: 8) {
                ForEach(bank, id: \.self) { i in
                    Button { if !checked { bank.removeAll { $0 == i }; placed.append(i); if bank.isEmpty { check(q) } } } label: { tile(tiles[i], on: false) }.buttonStyle(.plain)
                }
            }
            if !checked && !placed.isEmpty {
                Button("ล้าง") { bank += placed; placed = [] }.buttonStyle(InkButtonStyle(kind: .outline, height: 34)).frame(width: 90)
            }
        }
    }

    private func tile(_ s: String, on: Bool) -> some View {
        MixedText(s, size: 20, weight: .semibold, color: on ? Ink.onInk : Ink.ink)
            .padding(.horizontal, 14).frame(minHeight: 44)
            .background(on ? Ink.ink : Ink.card)
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
    }
}
