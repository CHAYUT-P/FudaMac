import SwiftUI
import AVFoundation

// 試 Exams: real JLPT N5 / N4 past tests and Fuda's original ones, taken like the
// real thing (timed sections in order, listening played once, answer sheet), the
// official rules, and a random-question quiz built from every exam.

enum ExamPage: Hashable { case hub, rules, random }

struct MacExamsView: View {
    @Environment(MacRouter.self) private var router

    var body: some View {
        if let run = router.examRun {
            ExamRunnerView(run: run)
        } else {
            switch router.examPage {
            case .hub: ExamHubView()
            case .rules: ExamRulesView()
            case .random: RandomExamView()
            }
        }
    }
}

// MARK: - Hub

struct ExamHubView: View {
    @Environment(MacRouter.self) private var router
    @Environment(ExamStore.self) private var exams

    var body: some View {
        @Bindable var router = router
        let sets = ExamLibrary.shared.sets(router.examLevel)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PaneHeader(kicker: "試験 · JLPT Exams", title: "ข้อสอบ \(router.examLevel.title)",
                           subtitle: "ข้อสอบจริงจากปีก่อนๆ ทำเหมือนวันสอบจริง: จับเวลาแต่ละพาร์ต · ฟังได้รอบเดียว · กระดาษคำตอบ") {
                    Segmented(options: [(Level.n5, "N5"), (Level.n4, "N4")], selection: $router.examLevel, height: 34).frame(width: 160)
                }

                HStack(spacing: 14) {
                    card("規", "กติกาการสอบ", "รูปแบบข้อสอบจริง เวลา จำนวนข้อ เกณฑ์ผ่าน และกฎในห้องสอบ") { router.examPage = .rules }
                    card("混", "สุ่มข้อสอบ · ฝึกทีละข้อ", "สุ่มคำถามจากข้อสอบทุกชุด ตอบแล้วดูเฉลยทันที เลือกชนิดข้อได้", accent: true) { router.examPage = .random }
                }

                group("ข้อสอบจริง · ครบทุกพาร์ต", "คำศัพท์ · ไวยากรณ์และการอ่าน · การฟังพร้อมเสียงจริง", sets.filter { $0.kind == .full })
                group("ข้อสอบจริง · ไม่ครบ", "บางชุดไม่มีพาร์ตฟัง หรือเป็นตัวอย่างสั้น คะแนนผ่าน/ตกจึงประเมินไม่ได้", sets.filter { $0.kind == .partial })
                group("ข้อสอบที่แต่งขึ้น", "Fuda แต่งขึ้นตามรูปแบบจริงทุกพาร์ต พาร์ตฟังใช้เสียงสังเคราะห์", sets.filter { $0.kind == .original })
                if sets.isEmpty {
                    Text("ยังไม่มีข้อสอบในเครื่องนี้").font(Typo.ui(15, .heavy)).foregroundStyle(Ink.soft)
                }
            }
            .padding(30)
        }
    }

    private func card(_ glyph: String, _ title: String, _ sub: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(glyph).font(Typo.mincho(26)).frame(width: 54, height: 54)
                    .foregroundStyle(accent ? Ink.onAkane : Ink.ink).background(accent ? Ink.akane : Ink.paper)
                    .overlay(Rectangle().strokeBorder(accent ? Ink.akane : Ink.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Typo.ui(16, .heavy))
                    Text(sub).font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(2)
                }
                Spacer()
                Text("›").font(.system(size: 20, weight: .heavy)).foregroundStyle(accent ? Ink.akane : Ink.ink)
            }
            .padding(14).frame(maxWidth: .infinity).inkBox().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func group(_ title: String, _ sub: String, _ sets: [ExamSet]) -> some View {
        if !sets.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title).font(Typo.ui(17, .heavy))
                    Text(sub).font(Typo.ui(12)).foregroundStyle(Ink.soft)
                }
                ForEach(sets) { row($0) }
            }
        }
    }

    private func row(_ s: ExamSet) -> some View {
        let best = exams.best(s.id)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(s.label).font(Typo.ui(16, .heavy))
                    Text(s.kindTH).font(.system(size: 10, weight: .heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                        .foregroundStyle(s.kind == .full ? Ink.onAkane : Ink.ink)
                        .background(s.kind == .full ? Ink.akane : Ink.chip)
                }
                Text(s.parts.map { "\($0.sectionTH) \($0.questions.count) ข้อ · \($0.minutes) นาที" }.joined(separator: "  ·  "))
                    .font(Typo.ui(12)).foregroundStyle(Ink.soft)
                if s.format == "old" && s.kind != .original {
                    Text("รูปแบบก่อนปี 2020 (ข้อและเวลามากกว่าปัจจุบันเล็กน้อย)").font(Typo.ui(11)).foregroundStyle(Ink.soft)
                }
            }
            Spacer()
            if let best {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ดีที่สุด \(best.score.total)\(best.score.listening == nil ? "/120" : "/180")").font(Typo.ui(13, .heavy))
                    if let p = best.score.passed(s.level) { Text(p ? "ผ่าน" : "ไม่ผ่าน").font(Typo.ui(11, .heavy)).foregroundStyle(p ? Ink.ink : Ink.akane) }
                }
            }
            Button {
                router.examRun = ExamRun(set: s)
            } label: { Text(best == nil ? "เริ่มสอบ" : "สอบอีกครั้ง").padding(.horizontal, 14) }
                .buttonStyle(InkButtonStyle(kind: .akane, height: 40)).fixedSize()
        }
        .padding(14).inkBox()
    }
}

// MARK: - Rules

struct ExamRulesView: View {
    @Environment(MacRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        let level = router.examLevel
        let secs = ExamRules.sections(level)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Button { router.examPage = .hub } label: { Text("‹ ข้อสอบ").font(Typo.ui(13, .bold)) }.buttonStyle(.plain)
                        .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Segmented(options: [(Level.n5, "N5"), (Level.n4, "N4")], selection: $router.examLevel, height: 34).frame(width: 160)
                }
                VStack(alignment: .leading, spacing: 4) {
                    TrackedLabel(text: "試験のルール · Exam rules")
                    Text("JLPT \(level.title) — รูปแบบข้อสอบจริง").font(Typo.mincho(32))
                    Text("รูปแบบปัจจุบัน (ตั้งแต่ปี 2020) · สอบ 3 ส่วนต่อเนื่องกัน รวม \(secs.reduce(0) { $0 + $1.minutes }) นาที · \(secs.flatMap(\.mondai).reduce(0) { $0 + $1.count }) ข้อ")
                        .font(Typo.ui(14)).foregroundStyle(Ink.soft)
                }

                ForEach(Array(secs.enumerated()), id: \.offset) { i, s in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("\(i + 1)").font(Typo.mincho(22)).foregroundStyle(Ink.onAkane).frame(width: 40, height: 40).background(Ink.akane)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.ja).font(Typo.mincho(20))
                                Text(s.th).font(Typo.ui(12)).foregroundStyle(Ink.soft)
                            }
                            Spacer()
                            Text("\(s.minutes) นาที · \(s.mondai.reduce(0) { $0 + $1.count }) ข้อ").font(Typo.ui(15, .heavy))
                        }
                        .padding(12)
                        ForEach(Array(s.mondai.enumerated()), id: \.offset) { j, m in
                            HStack {
                                Text("もんだい\(j + 1)").font(Typo.mincho(14)).frame(width: 90, alignment: .leading)
                                Text(m.name).font(Typo.mincho(15)).frame(width: 150, alignment: .leading)
                                Text(m.th).font(Typo.ui(13)).foregroundStyle(Ink.soft)
                                Spacer()
                                Text("\(m.count) ข้อ").font(Typo.ui(13, .heavy))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(j % 2 == 0 ? Ink.card : Ink.paper)
                        }
                    }
                    .inkBox()
                }

                VStack(alignment: .leading, spacing: 10) {
                    TrackedLabel(text: "คะแนนและเกณฑ์ผ่าน", color: Ink.ink)
                    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                        GridRow { cell("ส่วนคะแนน", head: true); cell("เต็ม", head: true); cell("ขั้นต่ำต่อส่วน", head: true) }
                        GridRow { cell("言語知識（文字・語彙・文法）・読解"); cell("120"); cell("38") }
                        GridRow { cell("聴解 การฟัง"); cell("60"); cell("19") }
                        GridRow { cell("รวม", head: false, bold: true); cell("180", bold: true); cell("ผ่านเมื่อได้ ≥ \(ExamRules.passMark(level)) และทุกส่วนถึงขั้นต่ำ", bold: true) }
                    }
                    .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
                    Text("ใน \(level.title) คำศัพท์ ไวยากรณ์ และการอ่าน รวมเป็นคะแนนส่วนเดียว (120) ส่วนการฟังแยก (60) ถ้าส่วนใดต่ำกว่าขั้นต่ำ ถือว่าตกแม้คะแนนรวมถึงเกณฑ์ คะแนนจริงเป็นคะแนนปรับมาตรฐาน (scaled) แอปประเมินจากสัดส่วนข้อที่ถูก")
                        .font(Typo.ui(13)).fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    TrackedLabel(text: "กฎในห้องสอบ · และโหมดสอบของแอป", color: Ink.ink)
                    rule("สอบตามลำดับ: คำศัพท์ → ไวยากรณ์·การอ่าน → (พัก) → การฟัง", "แอปเปิดทีละส่วนตามลำดับเดียวกัน")
                    rule("แต่ละส่วนมีเวลาของตัวเอง ทำเสร็จก่อนได้ แต่ย้อนกลับไปส่วนที่ส่งแล้วไม่ได้", "มีตัวจับเวลา หมดเวลาจะส่งอัตโนมัติ")
                    rule("ภายในส่วนเดียวกัน ข้ามไปมาระหว่างข้อได้ตามสบาย", "กดเลขข้อในกระดาษคำตอบเพื่อไปที่ข้อนั้น")
                    rule("การฟัง: เสียงเล่นครั้งเดียว ไม่หยุด ไม่ย้อน ต้องตอบระหว่างฟัง", "ข้อสอบจริงใช้เสียงบันทึกจริง ข้อสอบที่แต่งขึ้นใช้เสียงสังเคราะห์")
                    rule("ตอบลงกระดาษคำตอบ (マークシート) ข้อละหนึ่งคำตอบ ไม่มีหักคะแนนเมื่อตอบผิด", "จึงควรตอบทุกข้อ แม้จะเดา")
                    rule("ห้ามใช้พจนานุกรม โทรศัพท์ หรือโน้ต · ไม่มีฟุริงานะบนคันจิในระดับ", "โหมดสอบปิดฟุริงานะและโรมาจิทั้งหมด")
                    rule("ผลสอบ: คะแนนแต่ละส่วนและผ่าน/ไม่ผ่าน", "แอปแสดงคะแนนประเมิน ผ่าน/ไม่ผ่าน และเฉลยทุกข้อพร้อมคำอธิบายภาษาไทย")
                }
                Button { router.examPage = .hub } label: { Text("ไปเลือกข้อสอบ →").padding(.horizontal, 18) }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 46)).fixedSize()
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(30)
        }
    }

    private func cell(_ s: String, head: Bool = false, bold: Bool = false) -> some View {
        Text(s).font(head ? Typo.ui(12, .heavy) : Typo.ui(14, bold ? .heavy : .regular))
            .foregroundStyle(head ? Ink.onInk : Ink.ink)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(head ? Ink.ink : Ink.card)
            .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 0.5))
    }

    private func rule(_ real: String, _ app: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("■").font(Typo.ui(11)).foregroundStyle(Ink.akane).padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(real).font(Typo.ui(14, .semibold)).fixedSize(horizontal: false, vertical: true)
                Text("แอป: \(app)").font(Typo.ui(12)).foregroundStyle(Ink.soft)
            }
        }
    }
}

// MARK: - Shared question rendering (no furigana, like the booklet)

enum ExamRender {
    /// ▲word▲ → underlined, like the tested word in the booklet.
    static func text(_ s: String, size: CGFloat, bold: Bool = false) -> Text {
        var out = Text("")
        for (i, piece) in s.components(separatedBy: "▲").enumerated() {
            var t = Text(piece).font(Typo.mincho(size, bold: bold))
            if i % 2 == 1 { t = t.underline(true, color: Ink.ink).font(Typo.mincho(size, bold: true)) }
            out = out + t
        }
        return out
    }
}

struct ExamPicture: View {
    let name: String
    var maxHeight: CGFloat = 260
    var body: some View {
        if let url = ExamLibrary.imageURL(name), let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().interpolation(.high).scaledToFit()
                .frame(maxHeight: maxHeight).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ExamPassage: View {
    let text: String
    var body: some View {
        if !text.isEmpty {
            ExamRender.text(text, size: 17)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.card).overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                .textSelection(.enabled)
        }
    }
}

/// One question: prompt, picture, and the choices. `picked` / `onPick` make it answerable;
/// `reveal` shows right / wrong and the per-choice notes.
struct ExamQuestionView: View {
    let q: ExamQ
    var picked: Int?
    var reveal = false
    var showSpoken = false
    var onPick: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(q.no)").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.onInk).frame(minWidth: 26, minHeight: 22).background(Ink.ink)
                if !q.prompt.isEmpty { ExamRender.text(q.prompt, size: 19).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
            }
            if !q.img.isEmpty { ExamPicture(name: q.img) }
            let numbered = q.options.allSatisfy { Int($0) != nil }
            if numbered {
                HStack(spacing: 10) {
                    ForEach(q.options.indices, id: \.self) { i in choice(i, label: q.options[i], compact: true) }
                }
                if showSpoken && !q.spokenOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(q.spokenOptions.indices, id: \.self) { i in
                            Text("\(i + 1). \(q.spokenOptions[i])").font(Typo.mincho(15)).foregroundStyle(i == q.answer ? Ink.akane : Ink.ink)
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(q.options.indices, id: \.self) { i in choice(i, label: q.options[i], compact: false) }
                }
            }
        }
    }

    private func choice(_ i: Int, label: String, compact: Bool) -> some View {
        let isPicked = picked == i
        let right = reveal && i == q.answer
        let wrong = reveal && isPicked && i != q.answer
        let bg: Color = right ? Ink.ink : wrong ? Ink.akane : isPicked ? Ink.chip : Ink.card
        let fg: Color = right ? Ink.onInk : wrong ? Ink.onAkane : Ink.ink
        return Button { onPick?(i) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 10) {
                    Text("\(i + 1)").font(Typo.ui(12, .heavy)).frame(width: 22, height: 22)
                        .foregroundStyle(isPicked && !reveal ? Ink.onAkane : fg)
                        .background(Circle().fill(isPicked && !reveal ? Ink.akane : .clear))
                        .overlay(Circle().strokeBorder(fg, lineWidth: 1.5))
                    if !compact { ExamRender.text(label, size: 18).foregroundStyle(fg) }
                    Spacer(minLength: 0)
                }
                if reveal, q.optionNotes.indices.contains(i), !q.optionNotes[i].isEmpty {
                    MixedText(q.optionNotes[i], size: 12, color: fg.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true).padding(.leading, 32)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: compact ? 80 : .infinity, alignment: .leading)
            .background(bg)
            .overlay(Rectangle().strokeBorder(isPicked || right ? fg : Ink.line, lineWidth: isPicked || right ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onPick == nil)
    }
}

/// Reads a listening question aloud (two voices, then the spoken choices).
enum ExamVoice {
    nonisolated(unsafe) private static var generation = 0
    static func play(_ q: ExamQ, onDone: (() -> Void)? = nil) {
        generation += 1
        let gen = generation
        let lines = ExamText.spokenLines(q)
        func step(_ i: Int) {
            guard gen == generation else { return }
            guard i < lines.count else { onDone?(); return }
            Speech.shared.say(lines[i].1, voice: lines[i].0) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { step(i + 1) }
            }
        }
        step(0)
    }
    static func stop() { generation += 1; Speech.shared.stop() }
}

/// The official listening track for one もんだい.
@Observable
final class ExamTrack: NSObject, AVAudioPlayerDelegate {
    private(set) var playing = false
    private(set) var progress: Double = 0
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var onEnd: (() -> Void)?

    func play(_ name: String, onEnd: @escaping () -> Void) {
        stop()
        guard let url = ExamLibrary.audioURL(name), let p = try? AVAudioPlayer(contentsOf: url) else { onEnd(); return }
        self.onEnd = onEnd
        player = p
        p.delegate = self
        p.play()
        playing = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let p = self.player, p.duration > 0 else { return }
            self.progress = p.currentTime / p.duration
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player?.stop(); player = nil
        playing = false; progress = 0
        onEnd = nil
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        let done = onEnd
        timer?.invalidate(); timer = nil
        playing = false; progress = 1
        onEnd = nil
        DispatchQueue.main.async { done?() }
    }
}

// MARK: - Taking an exam

@Observable
final class ExamRun: Identifiable {
    enum Phase: Equatable { case cover(Int), answering(Int), finished }
    let id = UUID()
    let exam: ExamSet
    var phase: Phase = .cover(0)
    var answers: [String: Int] = [:]
    var remaining = 0                  // seconds left in the current part
    var listenBlock = 0                // listening: the もんだい now playing
    var listenQuestion = 0             // listening without a track: the question being read
    var listeningDone = false
    var attempt: ExamAttempt?
    @ObservationIgnored let track = ExamTrack()

    init(set: ExamSet) { self.exam = set }

    var partIndex: Int {
        switch phase { case .cover(let i), .answering(let i): i; case .finished: exam.parts.count }
    }
    var part: ExamPart? { exam.parts.indices.contains(partIndex) ? exam.parts[partIndex] : nil }

    func start(_ i: Int) {
        phase = .answering(i)
        remaining = exam.parts[i].minutes * 60
        listenBlock = 0; listenQuestion = 0; listeningDone = false
        if exam.parts[i].isListening { playListening() }
    }

    func tick() {
        guard case .answering = phase else { return }
        // Listening runs on the audio, like the real test; other parts on the clock.
        if part?.isListening == true { return }
        remaining -= 1
        if remaining <= 0 { endPart() }
    }

    func endPart() {
        track.stop(); ExamVoice.stop()
        let i = partIndex
        if i + 1 < exam.parts.count { phase = .cover(i + 1) } else { finish() }
    }

    private func finish() {
        let qs = exam.questions
        let a = ExamAttempt(setID: exam.id, date: .now, answers: answers, score: ExamRules.score(exam, answers: answers),
                            correct: qs.filter { answers[$0.id] == $0.answer }.count, total: qs.count)
        attempt = a
        phase = .finished
    }

    // Listening: each もんだい's official track plays once; without one, each question is read aloud with answer time after it.
    private func playListening() {
        guard let p = part, p.isListening else { return }
        guard p.blocks.indices.contains(listenBlock) else { listeningDone = true; return }
        let b = p.blocks[listenBlock]
        if !b.audio.isEmpty, ExamLibrary.audioURL(b.audio) != nil {
            track.play(b.audio) { [weak self] in self?.nextBlock() }
        } else {
            listenQuestion = 0
            readQuestion()
        }
    }

    private func readQuestion() {
        guard let p = part, p.blocks.indices.contains(listenBlock) else { return }
        let qs = p.blocks[listenBlock].questions
        guard qs.indices.contains(listenQuestion) else { nextBlock(); return }
        let blockAtStart = listenBlock
        ExamVoice.play(qs[listenQuestion]) { [weak self] in
            // Answer time after each question, as in the real test.
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                guard let self, self.listenBlock == blockAtStart, case .answering = self.phase else { return }
                self.listenQuestion += 1
                self.readQuestion()
            }
        }
    }

    private func nextBlock() {
        guard case .answering = phase else { return }
        listenBlock += 1
        playListening()
    }

    func stopAll() { track.stop(); ExamVoice.stop() }
}

struct ExamRunnerView: View {
    @Environment(MacRouter.self) private var router
    @Environment(ExamStore.self) private var exams
    let run: ExamRun
    @State private var confirmQuit = false
    @State private var confirmEnd = false
    @State private var focus: String?
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch run.phase {
            case .cover(let i): cover(i)
            case .answering: answering
            case .finished: ExamResultView(run: run)
            }
        }
        .onReceive(clock) { _ in run.tick() }
        .onDisappear { run.stopAll() }
        .onChange(of: run.phase) { _, p in
            if p == .finished, let a = run.attempt { exams.record(a, questions: run.exam.questions) }
        }
        .alert("ออกจากการสอบ?", isPresented: $confirmQuit) {
            Button("ออก (ไม่บันทึก)", role: .destructive) { run.stopAll(); router.examRun = nil }
            Button("สอบต่อ", role: .cancel) {}
        } message: { Text("คำตอบในครั้งนี้จะไม่ถูกบันทึก") }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { if run.phase == .finished { router.examRun = nil } else { confirmQuit = true } } label: {
                Text(run.phase == .finished ? "‹ ข้อสอบ" : "✕ ออก").font(Typo.ui(13, .bold))
            }
            .buttonStyle(.plain).keyboardShortcut(.escape, modifiers: [])
            Text("JLPT \(run.exam.level.title)").font(.system(size: 11, weight: .heavy)).tracking(2)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Ink.ink).foregroundStyle(Ink.onInk)
            Text(run.exam.label).font(Typo.ui(16, .heavy))
            Spacer()
            if case .answering = run.phase, let p = run.part {
                Text(p.sectionJA).font(Typo.mincho(16))
                if p.isListening {
                    Text(run.listeningDone ? "เสียงจบแล้ว" : "▶ กำลังเล่น もんだい\(run.listenBlock + 1)").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
                } else {
                    Text(String(format: "%02d:%02d", max(0, run.remaining) / 60, max(0, run.remaining) % 60))
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundStyle(run.remaining < 180 ? Ink.akane : Ink.ink)
                }
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 14)
        .background(Ink.card)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }
    }

    // Before each part: what it is, how long, the rules.
    private func cover(_ i: Int) -> some View {
        let p = run.exam.parts[i]
        return VStack(spacing: 18) {
            Spacer()
            if i > 0 { Text("ส่วนที่ \(i) ส่งแล้ว · พักได้ก่อนเริ่มส่วนต่อไป").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.soft) }
            Text("\(i + 1) / \(run.exam.parts.count)").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
            Text(p.sectionJA).font(Typo.mincho(40))
            Text(p.sectionTH).font(Typo.ui(16)).foregroundStyle(Ink.soft)
            Text(p.isListening ? "\(p.questions.count) ข้อ · ประมาณ \(p.minutes) นาที" : "\(p.questions.count) ข้อ · \(p.minutes) นาที")
                .font(Typo.ui(20, .heavy))
            VStack(alignment: .leading, spacing: 6) {
                if p.isListening {
                    Text("• เสียงจะเล่นต่อเนื่องทีละもんだい ครั้งเดียว หยุดหรือย้อนไม่ได้").font(Typo.ui(14))
                    Text("• ดูรูป/ตัวเลือกบนจอ แล้วตอบระหว่างฟัง").font(Typo.ui(14))
                    if !run.exam.hasRealAudio { Text("• ชุดนี้ใช้เสียงสังเคราะห์อ่านบทสนทนา").font(Typo.ui(14)).foregroundStyle(Ink.soft) }
                } else {
                    Text("• ทำข้อไหนก่อนก็ได้ภายในส่วนนี้ · หมดเวลาจะส่งอัตโนมัติ").font(Typo.ui(14))
                    Text("• ส่งแล้วย้อนกลับมาแก้ไม่ได้ · ไม่มีฟุริงานะ").font(Typo.ui(14))
                }
            }
            .padding(16).inkBox()
            Button { run.start(i) } label: { HStack { Text(p.isListening ? "เริ่มฟัง" : "เริ่มทำ"); Kbd("↩", light: true) }.padding(.horizontal, 22) }
                .buttonStyle(InkButtonStyle(kind: .akane, height: 52)).fixedSize()
                .keyboardShortcut(.return, modifiers: [])
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var answering: some View {
        let p = run.part!
        let unanswered = p.questions.filter { run.answers[$0.id] == nil }.count
        return HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        ForEach(Array(p.blocks.enumerated()), id: \.offset) { bi, b in
                            if !p.isListening || bi == min(run.listenBlock, p.blocks.count - 1) || run.listeningDone {
                                block(b, listening: p.isListening)
                            }
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)
                    .padding(30)
                }
                .onChange(of: focus) { _, f in if let f { withAnimation { proxy.scrollTo(f, anchor: .top) } } }
            }
            answerSheet(p, unanswered: unanswered)
        }
        .alert("ส่งส่วนนี้?", isPresented: $confirmEnd) {
            Button("ส่ง", role: .destructive) { run.endPart() }
            Button("กลับไปทำต่อ", role: .cancel) {}
        } message: { Text(unanswered > 0 ? "ยังไม่ได้ตอบ \(unanswered) ข้อ · ส่งแล้วกลับมาแก้ไม่ได้" : "ส่งแล้วกลับมาแก้ไม่ได้") }
    }

    private func block(_ b: ExamBlock, listening: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(b.nameJA).font(Typo.mincho(20, bold: true))
                if !b.instructionJA.isEmpty { Text(b.instructionJA).font(Typo.mincho(14, bold: false)).foregroundStyle(Ink.soft).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 1.5).offset(y: 6) }
            if listening && !b.audio.isEmpty && run.track.playing {
                ProgressView(value: run.track.progress).tint(Ink.akane)
            }
            ExamPassage(text: b.passageJA)
            ForEach(b.questions) { q in
                ExamQuestionView(q: q, picked: run.answers[q.id]) { i in run.answers[q.id] = i }
                    .id(q.id)
                    .padding(14)
                    .background(focus == q.id ? Ink.akane.opacity(0.06) : .clear)
            }
        }
    }

    private func answerSheet(_ p: ExamPart, unanswered: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TrackedLabel(text: "解答用紙 · กระดาษคำตอบ", color: Ink.ink)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(p.blocks) { b in
                        Text(b.nameJA.components(separatedBy: "　").first ?? b.nameJA).font(Typo.mincho(12)).foregroundStyle(Ink.soft)
                        ForEach(b.questions) { q in
                            HStack(spacing: 6) {
                                Button { focus = q.id } label: { Text("\(q.no)").font(Typo.ui(12, .heavy)).frame(width: 26, alignment: .trailing) }.buttonStyle(.plain)
                                ForEach(q.options.indices, id: \.self) { i in
                                    let on = run.answers[q.id] == i
                                    Button { run.answers[q.id] = i; focus = q.id } label: {
                                        Text("\(i + 1)").font(Typo.ui(10, .heavy)).frame(width: 22, height: 22)
                                            .foregroundStyle(on ? Ink.onInk : Ink.soft)
                                            .background(Circle().fill(on ? Ink.ink : .clear))
                                            .overlay(Circle().strokeBorder(on ? Ink.ink : Ink.line, lineWidth: 1.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            Text(unanswered == 0 ? "ตอบครบแล้ว" : "ยังไม่ได้ตอบ \(unanswered) ข้อ").font(Typo.ui(12, .heavy)).foregroundStyle(unanswered == 0 ? Ink.ink : Ink.akane)
            if p.isListening {
                Button { confirmEnd = true } label: { Text(run.listeningDone ? "ส่งการฟัง →" : "ส่งก่อนเสียงจบ").frame(maxWidth: .infinity) }
                    .buttonStyle(InkButtonStyle(kind: run.listeningDone ? .akane : .outline, height: 44))
            } else {
                Button { confirmEnd = true } label: { Text("ส่งส่วนนี้ →").frame(maxWidth: .infinity) }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 44))
            }
        }
        .padding(18)
        .frame(width: 250)
        .background(Ink.card)
        .overlay(alignment: .leading) { Rectangle().fill(Ink.ink).frame(width: 2) }
    }
}

// MARK: - Results and review

struct ExamResultView: View {
    @Environment(MacRouter.self) private var router
    let run: ExamRun
    @State private var wrongOnly = true

    var body: some View {
        let set = run.exam
        let a = run.attempt!
        let score = a.score
        let pass = score.passed(set.level)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 30) {
                    StampBadge(text: pass == true ? "合格" : pass == false ? "不合格" : "済", size: 110)
                    VStack(alignment: .leading, spacing: 6) {
                        TrackedLabel(text: "結果 · ผลสอบ")
                        Text("\(score.total) / \(score.listening == nil ? 120 : 180)").font(Typo.mincho(46))
                        Text(pass == nil ? "ชุดนี้ไม่มีพาร์ตฟัง จึงบอกผ่าน/ไม่ผ่านไม่ได้ (ดูคะแนนส่วนความรู้)" :
                                pass! ? "ผ่าน! เกณฑ์ \(ExamRules.passMark(set.level)) คะแนน และทุกส่วนถึงขั้นต่ำ" : "ยังไม่ผ่าน · เกณฑ์ \(ExamRules.passMark(set.level)) คะแนน และแต่ละส่วนต้องถึงขั้นต่ำ")
                            .font(Typo.ui(14)).foregroundStyle(pass == false ? Ink.akane : Ink.ink)
                        Text("ถูก \(a.correct) จาก \(a.total) ข้อ · คะแนนประเมินจากสัดส่วนข้อที่ถูก").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                    }
                }
                HStack(spacing: 14) {
                    bar("言語知識・読解", score.knowledge, of: 120, min: ExamRules.sectionMinimums.knowledge)
                    if let l = score.listening { bar("聴解", l, of: 60, min: ExamRules.sectionMinimums.listening) }
                }
                // Per もんだい: where the points were lost.
                VStack(alignment: .leading, spacing: 6) {
                    TrackedLabel(text: "แยกตามもんだい", color: Ink.ink)
                    ForEach(set.parts) { p in
                        ForEach(p.blocks) { b in
                            let right = b.questions.filter { a.answers[$0.id] == $0.answer }.count
                            HStack {
                                Text(p.sectionJA).font(Typo.ui(11)).foregroundStyle(Ink.soft).frame(width: 150, alignment: .leading)
                                Text(b.nameJA).font(Typo.mincho(14)).frame(width: 240, alignment: .leading)
                                DotMeter(value: Double(right) / Double(max(1, b.questions.count)), count: 10, size: 7)
                                Text("\(right)/\(b.questions.count)").font(Typo.ui(12, .heavy)).foregroundStyle(right == b.questions.count ? Ink.ink : Ink.akane)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(16).inkBox()

                HStack {
                    Text("เฉลย").font(Typo.mincho(26))
                    Spacer()
                    Toggle("เฉพาะข้อที่ผิด", isOn: $wrongOnly).toggleStyle(.checkbox).font(Typo.ui(13, .bold))
                }
                ForEach(set.parts) { p in
                    let qs = p.questions.filter { !wrongOnly || a.answers[$0.id] != $0.answer }
                    if !qs.isEmpty {
                        Text(p.sectionJA).font(Typo.mincho(18, bold: true)).padding(.top, 6)
                        ForEach(qs) { q in ExamReviewCard(q: q, picked: a.answers[q.id]) }
                    }
                }
                HStack {
                    Button { router.examRun = ExamRun(set: set) } label: { Text("สอบชุดนี้อีกครั้ง").padding(.horizontal, 16) }
                        .buttonStyle(InkButtonStyle(kind: .outline, height: 44)).fixedSize()
                    Button { router.examRun = nil } label: { Text("กลับไปหน้าข้อสอบ").padding(.horizontal, 16) }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 44)).fixedSize()
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(30)
        }
    }

    private func bar(_ title: String, _ v: Int, of max: Int, min: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title).font(Typo.mincho(15)); Spacer(); Text("\(v) / \(max)").font(Typo.ui(15, .heavy)) }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.chip)
                    Rectangle().fill(v >= min ? Ink.ink : Ink.akane).frame(width: g.size.width * CGFloat(v) / CGFloat(max))
                    Rectangle().fill(Ink.akane).frame(width: 2).offset(x: g.size.width * CGFloat(min) / CGFloat(max))
                }
            }
            .frame(height: 14)
            Text("ขั้นต่ำ \(min)").font(Typo.ui(11)).foregroundStyle(Ink.soft)
        }
        .padding(14).frame(maxWidth: .infinity).inkBox()
    }
}

/// A question after answering: the choices marked, the Thai explanation, the lesson link.
struct ExamReviewCard: View {
    @Environment(MacRouter.self) private var router
    let q: ExamQ
    let picked: Int?

    var body: some View {
        let block = ExamLibrary.shared.block(of: q)
        VStack(alignment: .leading, spacing: 10) {
            if let block, !block.passageJA.isEmpty {
                DisclosureGroup("บทอ่าน") { ExamPassage(text: block.passageJA) }.font(Typo.ui(12, .bold))
            }
            ExamQuestionView(q: q, picked: picked, reveal: true, showSpoken: true)
            if q.isListening {
                Button { ExamVoice.play(q) } label: { HStack { Image(systemName: "speaker.wave.2.fill"); Text("ฟังอีกครั้ง (เสียงสังเคราะห์)") } }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 32)).fixedSize()
                DisclosureGroup("บทพูด") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(q.script, id: \.self) { Text($0).font(Typo.mincho(14, bold: false)).fixedSize(horizontal: false, vertical: true) }
                    }
                    .textSelection(.enabled)
                }
                .font(Typo.ui(12, .bold))
            }
            if picked == nil { Text("ไม่ได้ตอบ").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane) }
            if !q.explainTH.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Text("解説").font(.system(size: 11, weight: .heavy)).foregroundStyle(Ink.onInk).padding(.horizontal, 6).padding(.vertical, 3).background(Ink.ink)
                    MixedText(q.explainTH, size: 14).fixedSize(horizontal: false, vertical: true)
                }
            }
            let lessons = q.grammarKeys.compactMap { Course.shared.lesson(teaching: $0) }
            if let l = lessons.first {
                Button { router.openLesson(l.n, step: .notes) } label: { Text("ทบทวนไวยากรณ์นี้ → บทที่ \(l.n)").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane) }
                    .buttonStyle(.plain)
            }
        }
        .padding(16).inkBox()
    }
}

// MARK: - Random questions

struct RandomExamView: View {
    @Environment(MacRouter.self) private var router
    @Environment(ExamStore.self) private var exams
    @State private var levels: Set<Level> = [.n5, .n4]
    @State private var types: Set<String> = ["vocab", "grammar", "reading", "listening"]
    @State private var count = 20
    @State private var source = "all"
    @State private var questions: [ExamQ] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var score = 0
    @State private var finished = false
    @State private var results: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { ExamVoice.stop(); if questions.isEmpty { router.examPage = .hub } else { questions = []; finished = false } } label: {
                    Text(questions.isEmpty ? "‹ ข้อสอบ" : "‹ ตั้งค่าใหม่").font(Typo.ui(13, .bold))
                }
                .buttonStyle(.plain).keyboardShortcut(.escape, modifiers: [])
                Spacer()
                if !questions.isEmpty && !finished {
                    Text("ข้อ \(index + 1) / \(questions.count) · ถูก \(score)").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
                }
            }
            .padding(.horizontal, 26).padding(.vertical, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
            if questions.isEmpty { setup } else if finished { summary } else { question(questions[index]) }
        }
        .onDisappear { ExamVoice.stop() }
        .onAppear {
            guard router.debugRandom > 0 else { return }
            let pickFirst = router.debugRandom == 2
            router.debugRandom = 0
            start()
            if pickFirst, let q = questions.first { pick(q.answer == 0 ? 1 : 0, q) }
        }
    }

    private var pool: [ExamQ] {
        let lib = ExamLibrary.shared
        return lib.sets.filter { levels.contains($0.level) }.flatMap(\.questions).filter { q in
            types.contains(q.type) && (source != "missed" || (exams.misses[q.id] ?? 0) > (exams.rights[q.id] ?? 0))
        }
    }

    private var setup: some View {
        let n = pool.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    TrackedLabel(text: "ランダム · สุ่มข้อสอบ")
                    Text("ฝึกทีละข้อจากข้อสอบทุกชุด").font(Typo.mincho(30))
                    Text("ตอบแล้วเห็นเฉลยและคำอธิบายทันที · ข้อที่ผิดจะถูกจำไว้ให้ฝึกซ้ำ").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                }
                option("ระดับ") {
                    ForEach(Level.allCases) { l in chip(l.title, on: levels.contains(l)) { toggle(&levels, l) } }
                }
                option("ชนิดข้อ") {
                    ForEach(["vocab", "grammar", "reading", "listening"], id: \.self) { t in
                        chip("\(ExamText.typeTH[t] ?? t) \(["vocab": "คำศัพท์", "grammar": "ไวยากรณ์", "reading": "การอ่าน", "listening": "การฟัง"][t] ?? "")", on: types.contains(t)) { toggle(&types, t) }
                    }
                }
                option("จำนวนข้อ") {
                    ForEach([10, 20, 30, 50], id: \.self) { c in chip("\(c)", on: count == c) { count = c } }
                }
                option("มาจาก") {
                    chip("ทุกข้อ", on: source == "all") { source = "all" }
                    chip("ข้อที่เคยผิด (\(missedCount))", on: source == "missed") { source = "missed" }
                }
                if types.contains("listening") {
                    Text("ข้อฟังในโหมดสุ่มอ่านด้วยเสียงสังเคราะห์ทีละข้อ (เสียงจริงเป็นไฟล์ยาวทั้งตอน ใช้ในโหมดสอบเต็มชุด)").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                }
                Button { start() } label: { HStack { Text("เริ่ม \(min(count, n)) ข้อ"); Kbd("↩", light: true) }.padding(.horizontal, 22) }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 50)).fixedSize()
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(n == 0)
                Text("มีให้สุ่ม \(n) ข้อ").font(Typo.ui(12)).foregroundStyle(Ink.soft)
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(30)
        }
    }

    private var missedCount: Int { exams.misses.filter { $0.value > (exams.rights[$0.key] ?? 0) }.count }

    private func toggle<T: Hashable>(_ s: inout Set<T>, _ v: T) { if s.contains(v) { if s.count > 1 { s.remove(v) } } else { s.insert(v) } }

    private func option<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 10) {
            Text(title).font(Typo.ui(13, .heavy)).frame(width: 90, alignment: .leading)
            content()
        }
    }

    private func chip(_ s: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s).font(Typo.ui(13, .bold)).padding(.horizontal, 12).frame(height: 32)
                .foregroundStyle(on ? Ink.onInk : Ink.ink).background(on ? Ink.ink : .clear)
                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func start() {
        questions = Array(pool.shuffled().prefix(count))
        index = 0; picked = nil; score = 0; finished = false; results = [:]
        playIfListening()
    }

    private func playIfListening() {
        guard questions.indices.contains(index), questions[index].isListening else { return }
        let q = questions[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { ExamVoice.play(q) }
    }

    private func question(_ q: ExamQ) -> some View {
        let lib = ExamLibrary.shared
        let block = lib.block(of: q)
        let set = lib.set(of: q)
        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text(set?.level.title ?? "").font(.system(size: 11, weight: .heavy)).padding(.horizontal, 6).padding(.vertical, 2).background(Ink.ink).foregroundStyle(Ink.onInk)
                        Text(ExamText.typeTH[q.type] ?? "").font(Typo.mincho(13)).padding(.horizontal, 6).padding(.vertical, 2).background(Ink.chip)
                        Text("\(set?.label ?? "") · \(block?.nameJA ?? "")").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                    }
                    if let b = block, !b.instructionJA.isEmpty {
                        Text(b.instructionJA).font(Typo.mincho(14, bold: false)).foregroundStyle(Ink.soft).fixedSize(horizontal: false, vertical: true)
                    }
                    if let b = block { ExamPassage(text: b.passageJA) }
                    if q.isListening {
                        Button { ExamVoice.play(q) } label: { HStack { Image(systemName: "speaker.wave.2.fill"); Text("ฟัง"); Kbd("P", light: true) }.padding(.horizontal, 14) }
                            .buttonStyle(InkButtonStyle(kind: .ink, height: 40)).fixedSize()
                            .keyboardShortcut("p", modifiers: [])
                    }
                    ExamQuestionView(q: q, picked: picked, reveal: picked != nil, showSpoken: picked != nil) { i in
                        if picked == nil { pick(i, q) }
                    }
                    if picked != nil {
                        ExamReviewExtras(q: q)
                        Button { next() } label: { HStack { Text(index == questions.count - 1 ? "ดูผล" : "ข้อต่อไป"); Kbd("↩", light: true) }.padding(.horizontal, 18) }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 44)).fixedSize()
                            .keyboardShortcut(.return, modifiers: [])
                    }
                }
                .frame(maxWidth: 860, alignment: .leading)
                .padding(30)
            }
            // Number keys answer.
            VStack {
                ForEach(0..<4, id: \.self) { i in
                    Button("") { if picked == nil, q.options.indices.contains(i) { pick(i, q) } }
                        .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: []).opacity(0).frame(width: 0, height: 0)
                }
            }
        }
        .id(q.id)
    }

    private func pick(_ i: Int, _ q: ExamQ) {
        picked = i
        let right = i == q.answer
        if right { score += 1; Haptic.success() } else { Haptic.warning() }
        results[q.id] = right
        exams.mark(q, right: right)
    }

    private func next() {
        ExamVoice.stop()
        if index < questions.count - 1 { index += 1; picked = nil; playIfListening() } else { finished = true }
    }

    private var summary: some View {
        let wrong = questions.filter { results[$0.id] == false }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 24) {
                    StampBadge(text: score * 10 >= questions.count * 7 ? "良" : "再", size: 90)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(score) / \(questions.count)").font(Typo.mincho(44))
                        let byType = Dictionary(grouping: questions, by: \.type)
                        Text(["vocab", "grammar", "reading", "listening"].compactMap { t in
                            byType[t].map { qs in "\(ExamText.typeTH[t] ?? t) \(qs.filter { results[$0.id] == true }.count)/\(qs.count)" }
                        }.joined(separator: "  ·  ")).font(Typo.ui(14))
                    }
                }
                HStack {
                    Button { start() } label: { Text("สุ่มชุดใหม่").padding(.horizontal, 16) }.buttonStyle(InkButtonStyle(kind: .akane, height: 44)).fixedSize()
                    Button { questions = []; finished = false } label: { Text("ตั้งค่าใหม่").padding(.horizontal, 16) }.buttonStyle(InkButtonStyle(kind: .outline, height: 44)).fixedSize()
                }
                if !wrong.isEmpty {
                    Text("ข้อที่ผิด").font(Typo.mincho(24))
                    ForEach(wrong) { q in ExamReviewCard(q: q, picked: nil) }
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(30)
        }
    }
}

/// The explanation and lesson link under an answered random question.
struct ExamReviewExtras: View {
    @Environment(MacRouter.self) private var router
    let q: ExamQ
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if q.isListening && !q.script.isEmpty {
                DisclosureGroup("บทพูด") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(q.script, id: \.self) { Text($0).font(Typo.mincho(14, bold: false)).fixedSize(horizontal: false, vertical: true) }
                    }
                }
                .font(Typo.ui(12, .bold))
            }
            if !q.explainTH.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Text("解説").font(.system(size: 11, weight: .heavy)).foregroundStyle(Ink.onInk).padding(.horizontal, 6).padding(.vertical, 3).background(Ink.ink)
                    MixedText(q.explainTH, size: 14).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let l = q.grammarKeys.compactMap({ Course.shared.lesson(teaching: $0) }).first {
                Button { router.openLesson(l.n, step: .notes) } label: { Text("ทบทวนไวยากรณ์นี้ → บทที่ \(l.n)").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane) }
                    .buttonStyle(.plain)
            }
        }
        .padding(14).background(Ink.card)
    }
}
