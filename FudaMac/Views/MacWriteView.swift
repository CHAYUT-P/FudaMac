import SwiftUI

// 書 Handwriting: draw kana with the mouse or trackpad.
//   練習 Practice — see the romaji, write the kana, the on-device model checks it.
//   集める Collect — save your own drawings as a test set for the model (Tools/handwriting/eval_folder.py).

struct InkCanvas: View {
    @Binding var strokes: [[CGPoint]]
    var side: CGFloat = 380
    var lineWidth: CGFloat { side * 0.045 }
    @State private var current: [CGPoint] = []

    var body: some View {
        Canvas { ctx, size in
            // Guide: a dashed cross like a kanji practice square.
            var guide = Path()
            guide.move(to: CGPoint(x: size.width / 2, y: 0)); guide.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            guide.move(to: CGPoint(x: 0, y: size.height / 2)); guide.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(guide, with: .color(Ink.akane.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            for s in strokes + [current] where !s.isEmpty {
                var p = Path(); p.move(to: s[0])
                if s.count == 1 { p.addLine(to: CGPoint(x: s[0].x + 0.1, y: s[0].y)) }
                for pt in s.dropFirst() { p.addLine(to: pt) }
                ctx.stroke(p, with: .color(Ink.ink), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: side, height: side)
        .background(Ink.card)
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                let p = CGPoint(x: min(max(0, v.location.x), side), y: min(max(0, v.location.y), side))
                if let last = current.last, hypot(last.x - p.x, last.y - p.y) < 1.5 { return }
                current.append(p)
            }
            .onEnded { _ in
                if !current.isEmpty { strokes.append(current) }
                current = []
            })
    }
}

struct MacWriteView: View {
    @Environment(MacRouter.self) private var router
    @State private var samples = HandwritingSamples()
    @State private var mode = "practice"
    @State private var script = "both"
    @State private var strokes: [[CGPoint]] = []
    @State private var target = "あ"
    @State private var result: [(kana: String, p: Double)] = []
    @State private var seen: [Float]?
    @State private var checked = false
    @State private var score = (right: 0, total: 0)
    @State private var queue: [String] = []
    private let side: CGFloat = 380
    private var lineWidth: CGFloat { side * 0.045 }
    private let goal = 10

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    TrackedLabel(text: "書く · Handwriting")
                    Text(mode == "practice" ? "เขียนคานะ แล้วให้โมเดลตรวจ" : "เก็บลายมือของคุณเป็นชุดทดสอบ").font(Typo.mincho(24))
                }
                Spacer()
                Segmented(options: [("hira", "ひらがな"), ("kata", "カタカナ"), ("both", "ทั้งสอง")], selection: $script, height: 32).frame(width: 260)
                Segmented(options: [("practice", "練習 ฝึกเขียน"), ("collect", "集める เก็บตัวอย่าง")], selection: $mode, height: 32).frame(width: 300)
            }
            .padding(.horizontal, 30).padding(.vertical, 16)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }

            HStack(alignment: .top, spacing: 30) {
                prompt.frame(width: 220)
                VStack(spacing: 12) {
                    InkCanvas(strokes: $strokes, side: side)
                    HStack(spacing: 10) {
                        Button { if !strokes.isEmpty { strokes.removeLast(); checked = false } } label: { HStack { Image(systemName: "arrow.uturn.backward"); Text("ย้อนเส้น"); Kbd("⌘Z") } }
                            .buttonStyle(InkButtonStyle(kind: .outline, height: 40)).fixedSize()
                            .keyboardShortcut("z", modifiers: .command)
                        Button { clear() } label: { HStack { Text("ล้าง"); Kbd("⌫") } }
                            .buttonStyle(InkButtonStyle(kind: .outline, height: 40)).fixedSize()
                            .keyboardShortcut(.delete, modifiers: [])
                        Button { primary() } label: { HStack { Text(primaryLabel); Kbd("↩", light: true) }.padding(.horizontal, 10) }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 40)).fixedSize()
                            .keyboardShortcut(.return, modifiers: [])
                            .disabled(strokes.isEmpty && !checked)
                    }
                }
                side3.frame(width: 300)
            }
            .padding(30)
            Spacer(minLength: 0)
        }
        .onAppear { if queue.isEmpty { nextTarget() } }
        .onChange(of: script) { _, _ in queue = []; nextTarget() }
        .onChange(of: mode) { _, _ in queue = []; nextTarget() }
    }

    private var pool: [String] {
        script == "hira" ? KanaSet.hiragana : script == "kata" ? KanaSet.katakana : KanaSet.all
    }

    // MARK: left: what to write

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrackedLabel(text: mode == "practice" ? "เขียนตัวนี้" : "เขียนตามตัวนี้", color: Ink.ink)
            Text(KanaSet.isKatakana(target) ? "カタカナ" : "ひらがな").font(Typo.mincho(16)).foregroundStyle(Ink.akane)
            Text(KanaSet.romaji(target)).font(.system(size: 64, weight: .heavy, design: .rounded))
            if mode == "collect" || checked {
                Text(target).font(Typo.mincho(90)).frame(maxWidth: .infinity, alignment: .leading)
            }
            if mode == "practice" {
                Text("ถูก \(score.right) / \(score.total)").font(Typo.ui(14, .heavy)).foregroundStyle(Ink.akane)
            } else {
                Text("ตัวนี้เก็บแล้ว \(samples.counts[target] ?? 0) / \(goal)").font(Typo.ui(14, .heavy))
            }
            Spacer()
        }
        .padding(18).frame(height: side).inkBox()
    }

    // MARK: right: the model's answer, or collection progress

    @ViewBuilder private var side3: some View {
        if mode == "practice" { practicePanel } else { collectPanel }
    }

    private var practicePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !KanaReader.shared.available {
                TrackedLabel(text: "ยังไม่มีโมเดล", color: Ink.akane)
                Text("เทรนโมเดลใน Colab ด้วย Tools/handwriting/train_kana_colab.ipynb แล้ววางไฟล์ KanaRecognizer.mlpackage ไว้ใน FudaMac/Resources แล้ว build ใหม่")
                    .font(Typo.ui(13)).fixedSize(horizontal: false, vertical: true)
                Text("ระหว่างนี้ไปที่ 集める เก็บตัวอย่างลายมือของคุณไว้ใช้ทดสอบโมเดลได้เลย").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                    .fixedSize(horizontal: false, vertical: true)
            } else if checked {
                let ok = result.first.map { KanaSet.sameShape($0.kana, target) } ?? false
                HStack(spacing: 12) {
                    StampBadge(text: ok ? "正" : "誤", size: 64)
                    Text(ok ? "ถูกต้อง" : "โมเดลอ่านเป็น「\(result.first?.kana ?? "?")」").font(Typo.ui(16, .heavy))
                }
                TrackedLabel(text: "โมเดลเดา", color: Ink.ink)
                ForEach(Array(result.enumerated()), id: \.offset) { _, g in
                    HStack(spacing: 10) {
                        Text(g.kana).font(Typo.mincho(26)).frame(width: 34)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Ink.chip)
                                Rectangle().fill(KanaSet.sameShape(g.kana, target) ? Ink.ink : Ink.akane).frame(width: geo.size.width * g.p)
                            }
                        }
                        .frame(height: 12)
                        Text("\(Int((g.p * 100).rounded()))%").font(Typo.ui(12, .heavy)).frame(width: 40, alignment: .trailing)
                    }
                }
                if let seen {
                    TrackedLabel(text: "ภาพที่โมเดลเห็น (64×64)", color: Ink.ink)
                    Image(nsImage: HandwritingPrep.image(seen)).interpolation(.none).resizable().frame(width: 128, height: 128)
                        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
                }
                Text("โมเดลดูแค่รูปร่าง ไม่ได้ตรวจลำดับขีด · へ กับ ヘ เขียนเหมือนกันจึงนับว่าถูกทั้งคู่").font(Typo.ui(11)).foregroundStyle(Ink.soft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TrackedLabel(text: "วิธีใช้", color: Ink.ink)
                Text("เขียนคานะตามเสียงทางซ้ายลงในช่อง แล้วกด ↩ ให้โมเดลบนเครื่องตรวจ\nเขียนให้ใหญ่เต็มช่อง ใช้เมาส์หรือแทร็กแพด").font(Typo.ui(13)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18).frame(height: side).inkBox()
    }

    private var collectPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrackedLabel(text: "ชุดทดสอบของคุณ", color: Ink.ink)
            let done = pool.filter { (samples.counts[$0] ?? 0) >= goal }.count
            Text("\(samples.total) ภาพ · ครบ \(goal) แล้ว \(done)/\(pool.count) ตัว").font(Typo.ui(14, .heavy))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 3), count: 10), spacing: 3) {
                    ForEach(pool, id: \.self) { k in
                        let n = samples.counts[k] ?? 0
                        Button { target = k; strokes = [] } label: {
                            Text(k).font(Typo.mincho(12)).frame(width: 24, height: 24)
                                .foregroundStyle(n >= goal ? Ink.onInk : Ink.ink)
                                .background(n >= goal ? Ink.ink : n > 0 ? Ink.chip : Ink.card)
                                .overlay(Rectangle().strokeBorder(k == target ? Ink.akane : Ink.line, lineWidth: k == target ? 2 : 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("ใช้วัดความแม่นยำกับลายมือจริงของคุณ: คัดลอกโฟลเดอร์ไป Google Drive (fuda-hw/my_samples) แล้วรัน eval_folder.py ใน Colab")
                .font(Typo.ui(11)).foregroundStyle(Ink.soft).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("เปิดโฟลเดอร์") { samples.reveal() }.buttonStyle(InkButtonStyle(kind: .outline, height: 34)).fixedSize()
                Button("ลบภาพล่าสุดของตัวนี้") { samples.undoLast(target) }.buttonStyle(InkButtonStyle(kind: .outline, height: 34)).fixedSize()
                    .disabled((samples.counts[target] ?? 0) == 0)
            }
        }
        .padding(18).frame(height: side).inkBox()
    }

    // MARK: actions

    private var primaryLabel: String {
        mode == "collect" ? "บันทึก แล้วตัวต่อไป" : checked ? "ตัวต่อไป" : "ตรวจ"
    }

    private func primary() {
        if mode == "collect" {
            guard !strokes.isEmpty, let png = HandwritingPrep.png(strokes, canvas: side, lineWidth: lineWidth) else { return }
            samples.save(png, kana: target)
            nextTarget()
        } else if checked {
            nextTarget()
        } else {
            guard KanaReader.shared.available, let px = HandwritingPrep.pixels(strokes, lineWidth: lineWidth) else { return }
            seen = px
            result = KanaReader.shared.read(px)
            checked = true
            let ok = result.first.map { KanaSet.sameShape($0.kana, target) } ?? false
            score = (score.right + (ok ? 1 : 0), score.total + 1)
        }
    }

    private func clear() { strokes = []; checked = false; result = []; seen = nil }

    private func nextTarget() {
        clear()
        if mode == "collect" {
            // The kana with the fewest saved drawings comes next.
            let least = pool.min { (samples.counts[$0] ?? 0) < (samples.counts[$1] ?? 0) } ?? pool[0]
            let n = samples.counts[least] ?? 0
            target = pool.filter { (samples.counts[$0] ?? 0) == n }.randomElement() ?? least
        } else {
            if queue.isEmpty { queue = pool.shuffled() }
            target = queue.removeFirst()
        }
    }
}
