import SwiftUI

// 学ぶ Learn: one tab per grammar point. Points with a purpose-built
// infographic show it; every other point gets the generic explainer (formula
// blocks, examples, mistakes, register). The right rail always has the one-line
// rule, key points and a check question.

struct LearnStepView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    var showFooter = true
    var step: LessonStep = .learn            // the lesson step this view counts toward
    var nextStep: LessonStep? = .words       // where the last point leads

    private var index: Int {
        get { router.learnPoint }
        nonmutating set { router.learnPoint = newValue }
    }

    var body: some View {
        let points = lesson.grammarCards.compactMap(\.grammarItem)
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(points.indices, id: \.self) { i in
                        let on = i == index
                        Button { index = i } label: {
                            HStack(spacing: 10) {
                                Text(String(format: "%02d", i + 1)).font(Typo.ui(11, .heavy)).foregroundStyle(on ? Ink.akane : Ink.soft)
                                VStack(alignment: .leading, spacing: 0) {
                                    MixedText(points[i].pattern, size: 15, weight: .bold)
                                    Text(points[i].en).font(Typo.ui(11, .bold)).opacity(0.75).lineLimit(1)
                                }
                                if course.points.contains(points[i].key) { Text("✓").font(Typo.ui(12, .heavy)).foregroundStyle(Ink.akane) }
                            }
                            .padding(.horizontal, 16).frame(height: 52)
                            .foregroundStyle(Ink.ink).opacity(on ? 1 : 0.7)
                            .background(on ? Ink.card : .clear)
                            .overlay(alignment: .bottom) { Rectangle().fill(on ? Ink.akane : .clear).frame(height: 4) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }

            if points.indices.contains(index) {
                let g = points[index]
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        LearnModeBar(hasPlayground: Self.hasPlayground(g.key), handmade: LessonScripts.isHandmade(g.key))
                        switch router.learnMode {
                        case .lesson:
                            LessonPlayer(title: g.pattern, beats: LessonScripts.beats(for: g), start: router.debugBeat) {
                                if index < points.count - 1 { index += 1 } else if let nextStep { router.step = nextStep }
                            }
                            .padding(20)
                            .id("lesson-\(g.key)-\(router.debugBeat)")
                        case .play where Self.hasPlayground(g.key):
                            ScrollView { playground(g).padding(28) }
                        default:
                            ScrollView { GrammarExplainer(point: g).padding(28) }
                        }
                    }
                    LearnRail(point: g, isLast: index == points.count - 1, nextStep: nextStep,
                              prev: index > 0 ? { index -= 1 } : nil,
                              next: { if index < points.count - 1 { index += 1 } }) {
                        course.markPoint(g.key)
                        if points.allSatisfy({ course.points.contains($0.key) }) { course.complete(lesson.n, step) }
                    }
                    .id(g.key)
                }
            }
            if showFooter { StepFooter(lesson: lesson, step: .learn) }
        }
    }

    static func hasPlayground(_ key: String) -> Bool {
        ["n5.v.te", "n5.t.kudasai", "n5.t.teiru", "n5.t.teiru2", "n5.t.connect"].contains(key)
    }

    @ViewBuilder private func playground(_ g: GrammarItem) -> some View {
        switch g.key {
        case "n5.v.te": TeMachineView()
        case "n5.t.kudasai": PolitenessLadderView()
        case "n5.t.teiru": TeiruTimelineView(state: false)
        case "n5.t.teiru2": TeiruTimelineView(state: true)
        case "n5.t.connect": TeChainView()
        default: GrammarExplainer(point: g)
        }
    }
}

enum LearnMode: String { case lesson, play, notes }

/// ▶ Lesson (animated, narrated) · ◇ Play (hands-on infographic) · 文 Notes (full reference).
struct LearnModeBar: View {
    @Environment(MacRouter.self) private var router
    let hasPlayground: Bool
    let handmade: Bool
    var body: some View {
        HStack(spacing: 0) {
            item(.lesson, "▶", "Lesson", handmade ? "animated" : "guided")
            if hasPlayground { item(.play, "◇", "Play", "try it yourself") }
            item(.notes, "文", "Notes", "full reference")
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 12)
    }
    private func item(_ m: LearnMode, _ glyph: String, _ title: String, _ sub: String) -> some View {
        let on = router.learnMode == m || (m == .notes && router.learnMode == .play && !hasPlayground)
        return Button { router.learnMode = m } label: {
            HStack(spacing: 8) {
                Text(glyph).font(Typo.mincho(15))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(Typo.ui(13, .heavy))
                    Text(sub).font(Typo.ui(10)).opacity(0.75)
                }
            }
            .padding(.horizontal, 14).frame(height: 44)
            .foregroundStyle(on ? Ink.onInk : Ink.ink)
            .background(on ? Ink.ink : .clear)
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Right rail

struct LearnRail: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router
    let point: GrammarItem
    let isLast: Bool
    var nextStep: LessonStep? = .words
    let prev: (() -> Void)?
    let next: () -> Void
    let onCorrect: () -> Void
    @State private var picked: Int?

    var body: some View {
        let info = LearnInfo.for(point)
        let check = LearnInfo.check(point)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    TrackedLabel(text: "In one line", color: Ink.akane, size: 10)
                    MixedText(info.big, size: 17, weight: .heavy)
                    MixedText(info.th, size: 14, color: Ink.soft)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(info.bullets, id: \.self) { b in
                        HStack(alignment: .top, spacing: 10) {
                            Rectangle().fill(Ink.ink).frame(width: 7, height: 7).padding(.top, 6)
                            MixedText(b, size: 13)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
                    }
                }
                if let check {
                    VStack(alignment: .leading, spacing: 8) {
                        TrackedLabel(text: "確認 · Check yourself", color: Ink.ink, size: 10)
                        MixedText(check.q, size: 17, weight: .semibold)
                        ForEach(check.options.indices, id: \.self) { i in
                            let st: (Color, Color, Color, Double) = picked == nil ? (Ink.paper, Ink.ink, Ink.ink, 1) : i == check.answer ? (Ink.ink, Ink.onInk, Ink.ink, 1) : i == picked ? (Ink.akane, Ink.onAkane, Ink.akane, 1) : (Ink.paper, Ink.ink, Ink.ink, 0.4)
                            Button {
                                guard picked == nil else { return }
                                picked = i
                                if i == check.answer { Haptic.success(); onCorrect() } else { Haptic.warning() }
                            } label: {
                                MixedText(check.options[i], size: 15, weight: .semibold, color: st.1)
                                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading).padding(.horizontal, 10)
                                    .foregroundStyle(st.1).background(st.0)
                                    .overlay(Rectangle().strokeBorder(st.2, lineWidth: 2)).opacity(st.3)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        MixedText(picked == nil ? "Pick an answer. Getting it right ticks this point." : (picked == check.answer ? "正解! " : "Not quite. ") + check.explain, size: 12, color: Ink.soft)
                    }
                    .padding(14).inkBox()
                }
                HStack(spacing: 8) {
                    Button { prev?() } label: { Text("←") }
                        .buttonStyle(InkButtonStyle(kind: .outline, height: 44)).frame(width: 50)
                        .disabled(prev == nil)
                        .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
                    Button { if isLast { if let nextStep { router.step = nextStep } } else { next() } } label: {
                        Text(isLast ? (nextStep.map { "Go to \($0.en) \($0.ja) →" } ?? "Done ✓") : "Next point →")
                    }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 44))
                        .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
                }
            }
            .padding(22)
        }
        .frame(width: 330)
        .background(Ink.chip.opacity(0.6))
        .overlay(alignment: .leading) { Rectangle().fill(Ink.ink).frame(width: 2) }
    }
}

struct LearnCheck { let q: String; let options: [String]; let answer: Int; let explain: String }

enum LearnInfo {
    struct Info { let big: String; let th: String; let bullets: [String] }

    static func `for`(_ g: GrammarItem) -> Info {
        switch g.key {
        case "n5.v.te": return Info(big: "て-form is the verb's \"connector\" shape. Make it once, use it everywhere.", th: "รูปเทะคือรูปเชื่อมของกริยา ทำได้ครั้งเดียวใช้ได้ทุกที่",
            bullets: ["Group 1 changes by its last sound; Group 2 drops る; する / 来る are irregular.", "行く is the only exception in the く row: 行って.", "The same rules make the た-form in Lesson 11: 飲んで → 飲んだ."])
        case "n5.t.kudasai": return Info(big: "Vて + ください = \"please do V\". The polite way to ask anyone.", th: "Vて + ください = กรุณา… ใช้ขอร้องอย่างสุภาพ",
            bullets: ["Drop ください with friends: ちょっと待って.", "To say \"please don't\", use the ない-form: 〜ないでください.", "Add ませんか to soften it further (N4)."])
        case "n5.t.teiru": return Info(big: "Vて + いる = the action is happening right now, or happens habitually.", th: "Vて + いる = กำลังทำอยู่ หรือทำเป็นประจำ",
            bullets: ["今、食べています: NOW sits inside the action.", "With 毎朝 or いつも it means a habit: 毎朝走っています.", "Casual speech drops the い: 食べてる."])
        case "n5.t.teiru2": return Info(big: "With \"change\" verbs, ている means the result is still true.", th: "กริยาที่เปลี่ยนสภาพทันที + ている = สภาพที่เป็นอยู่หลังจากนั้น",
            bullets: ["結婚しています = is married, not \"is marrying\".", "知っています = I know. Its negative is 知りません, not 知っていません.", "Instant verbs: 結婚する · 知る · 住む · 来る · 行く · 死ぬ."])
        case "n5.t.connect": return Info(big: "Join actions with て. Only the last verb carries the tense.", th: "เชื่อมการกระทำด้วย て กาลอยู่ที่กริยาตัวสุดท้ายเท่านั้น",
            bullets: ["Sequence: do A, then B, then C.", "Reason: 風邪をひいて休みました, \"I caught a cold, so I rested\".", "Manner: 歩いて行きます, \"I go on foot\"."])
        default:
            var bullets: [String] = []
            if !g.formationEN.isEmpty { bullets.append(g.formationEN) }
            if !g.mistakesEN.isEmpty { bullets.append("Watch out: " + g.mistakesEN) }
            if !g.registerEN.isEmpty { bullets.append(g.registerEN) }
            if bullets.isEmpty { bullets = sentences(g.explainEN).prefix(3).map { $0 } }
            return Info(big: "\(g.pattern) = \(g.en)", th: g.th, bullets: bullets)
        }
    }

    static func check(_ g: GrammarItem) -> LearnCheck? {
        switch g.key {
        case "n5.v.te": return LearnCheck(q: "遊ぶ → て形 ?", options: ["遊って", "遊んで", "遊いで"], answer: 1, explain: "む・ぶ・ぬ → んで: 遊んで.")
        case "n5.t.kudasai": return LearnCheck(q: "To a teacher: 「名前を＿＿」", options: ["書け", "書いてください", "書く"], answer: 1, explain: "With a teacher, use the polite request: 書いてください.")
        case "n5.t.teiru": return LearnCheck(q: "\"I am reading a book right now.\"", options: ["本を読みます", "本を読んでいます", "本を読みました"], answer: 1, explain: "In progress now = 〜ています.")
        case "n5.t.teiru2": return LearnCheck(q: "田中さんは結婚＿＿。 (is married)", options: ["します", "しています", "しました"], answer: 1, explain: "A change verb + ている = the state now: 結婚しています.")
        case "n5.t.connect": return LearnCheck(q: "\"I ate and then slept.\"", options: ["食べて、寝ました", "食べました、寝て", "食べて、寝ます"], answer: 0, explain: "て links the actions; the last verb carries past tense: 寝ました.")
        default:
            if let e = g.exercises.first(where: \.isChoice) {
                return LearnCheck(q: e.prompt, options: e.options, answer: e.answer, explain: e.explainEN.isEmpty ? e.explainTH : e.explainEN)
            }
            let peers = DB.shared.grammar.filter { $0.level == g.level && $0.key != g.key }.shuffled().prefix(2).map(\.en)
            guard peers.count == 2 else { return nil }
            var opts = Array(peers)
            let at = abs(g.key.hashValue) % 3
            opts.insert(g.en, at: at)
            return LearnCheck(q: "What does \(g.pattern) mean?", options: opts, answer: at, explain: "\(g.pattern) = \(g.en) · \(g.th)")
        }
    }

    static func sentences(_ s: String) -> [String] {
        s.components(separatedBy: ". ").map { $0.hasSuffix(".") ? $0 : $0 + "." }.filter { $0.count > 3 }
    }
}

// MARK: - Generic explainer

struct GrammarExplainer: View {
    @Environment(ProgressStore.self) private var store
    let point: GrammarItem

    var body: some View {
        let g = point
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                TrackedLabel(text: category(g.cat), color: Ink.akane)
                Text(g.pattern).font(Typo.mincho(36)).textSelection(.enabled)
                MixedText("\(g.en) · \(g.th)", size: 15, color: Ink.soft)
            }

            // Formula: the structure as blocks.
            VStack(alignment: .leading, spacing: 8) {
                TrackedLabel(text: "The formula", color: Ink.ink, size: 10)
                Flow(spacing: 8) {
                    ForEach(Array(formula(g.structure).enumerated()), id: \.offset) { i, part in
                        if part == "+" || part == "→" || part == "/" {
                            Text(part).font(Typo.ui(18, .heavy)).foregroundStyle(Ink.akane).frame(height: 44)
                        } else {
                            Text(part).font(Typo.mincho(18))
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .foregroundStyle(i == 0 ? Ink.onInk : Ink.ink)
                                .background(i == 0 ? Ink.ink : Ink.card)
                                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
                        }
                    }
                }
            }

            MixedText(store.settings.showEnglish ? g.explainEN : g.explainTH, size: 15)
                .frame(maxWidth: 760, alignment: .leading).textSelection(.enabled)
            if store.settings.showEnglish && !g.explainTH.isEmpty {
                MixedText(g.explainTH, size: 13, color: Ink.soft).frame(maxWidth: 760, alignment: .leading)
            }

            if !g.formationEN.isEmpty || !g.formationTH.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    TrackedLabel(text: "作り方 · How to make it", color: Ink.ink, size: 10)
                    ForEach(formationLines(g.formationEN.isEmpty ? g.formationTH : g.formationEN), id: \.self) { line in
                        MixedText(line, size: 15).padding(.vertical, 6).padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading).inkBox(width: 1.5)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TrackedLabel(text: "例文 · Examples", color: Ink.ink, size: 10)
                ForEach(Array(g.examples.prefix(4).enumerated()), id: \.offset) { _, e in
                    HStack(alignment: .top, spacing: 12) {
                        SentenceBlock(ja: e.ja, kana: e.kana, romaji: e.romaji, th: e.th, en: e.en, size: 20, highlight: mark(e.ja, g.pattern))
                        Spacer()
                        SpeakIcon(text: e.kana)
                    }
                    .padding(14).inkBox()
                }
            }

            GrammarInConversation(keys: [g.key], pattern: g.pattern)

            HStack(alignment: .top, spacing: 14) {
                if !g.mistakesEN.isEmpty || !g.mistakesTH.isEmpty {
                    note("注意 · Common mistake", g.mistakesEN.isEmpty ? g.mistakesTH : g.mistakesEN, g.mistakesEN.isEmpty ? "" : g.mistakesTH, accent: true)
                }
                if !g.registerEN.isEmpty || !g.registerTH.isEmpty {
                    note("使い方 · Register", g.registerEN.isEmpty ? g.registerTH : g.registerEN, g.registerEN.isEmpty ? "" : g.registerTH, accent: false)
                }
            }
        }
    }

    private func note(_ title: String, _ body: String, _ th: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TrackedLabel(text: title, color: accent ? Ink.akane : Ink.soft, size: 10)
            MixedText(body, size: 14)
            if !th.isEmpty { MixedText(th, size: 12, color: Ink.soft) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .topLeading)
        .inkBox(Ink.card, border: accent ? Ink.akane : Ink.ink)
    }

    private func category(_ c: String) -> String {
        switch c {
        case "structures": "基本文型 · Sentence structure"; case "particles": "助詞 · Particle"; case "verbForms": "動詞の形 · Verb form"
        case "teUses": "て形 · Te-form use"; case "patterns": "文型 · Pattern"; case "conditionals": "条件 · Conditional"; case "honorifics": "敬語 · Keigo"
        default: c
        }
    }

    /// "Vます → V + たい" → ["Vます", "→", "V", "+", "たい"]
    private func formula(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s {
            if ch == "+" || ch == "→" || ch == "＋" || (ch == "/" && !cur.isEmpty) {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { out.append(t) }
                out.append(ch == "＋" ? "+" : String(ch))
                cur = ""
            } else { cur.append(ch) }
        }
        let t = cur.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { out.append(t) }
        return out.count > 9 ? [s] : out
    }

    private func formationLines(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet(charactersIn: "|;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func mark(_ ja: String, _ pattern: String) -> String? {
        let core = LessonScripts.coreOf(pattern)
        return !core.isEmpty && ja.contains(core) ? core : nil
    }
}

/// Where a grammar point is used in the lesson conversations: one line with a
/// friend and one polite line, each opening its conversation.
struct GrammarInConversation: View {
    @Environment(MacRouter.self) private var router
    let keys: [String]
    var pattern: String = ""

    var body: some View {
        let uses = keys.flatMap { Talk.lines(using: $0) }
        let picks = [uses.first { $0.scene.isCasual }, uses.first { !$0.scene.isCasual }].compactMap { $0 }
        if !picks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TrackedLabel(text: "会話で · ใช้ในบทสนทนา · In conversation (\(uses.count))", color: Ink.ink, size: 10)
                ForEach(picks, id: \.line.ja) { u in
                    Button { router.lessonN = nil; router.talkID = u.scene.id; router.section = .talk } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 2) {
                                Text(u.scene.registerJA).font(Typo.mincho(13))
                                Text(u.scene.isCasual ? "Casual" : "Polite").font(.system(size: 9, weight: .heavy))
                            }
                            .frame(width: 64, height: 40)
                            .foregroundStyle(Ink.onInk).background(u.scene.isCasual ? Ink.akane : Ink.ink)
                            SentenceBlock(ja: u.line.ja, kana: u.line.kana, romaji: u.line.romaji, th: u.line.th, en: u.line.en, size: 18, highlight: highlight(u.line.ja))
                            Spacer()
                            Text("\(u.scene.title) →").font(Typo.ui(11, .heavy)).foregroundStyle(Ink.akane).lineLimit(1)
                        }
                        .padding(12).inkBox().contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func highlight(_ ja: String) -> String? {
        let core = LessonScripts.coreOf(pattern)
        return !core.isEmpty && ja.contains(core) ? core : nil
    }
}

// MARK: - Kana lesson

struct KanaLearnView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router
    let lesson: CourseLesson
    @State private var script: KanaItem.Script = .hira
    @State private var group: KanaItem.Group = .base
    @State private var lit: String?

    var body: some View {
        let rows = KanaData.chart(script, group)
        let cols = group == .yoon ? 3 : 5
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Segmented(options: KanaItem.Script.allScripts.map { ($0, $0.ja) }, selection: $script, height: 36)
                        Segmented(options: KanaItem.Group.allCases.map { ($0, $0.en) }, selection: $group, height: 36)
                        Spacer()
                    }
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(group == .yoon ? 120 : 92), spacing: 8), count: cols), alignment: .leading, spacing: 8) {
                            ForEach(Array(rows.joined().enumerated()), id: \.offset) { _, item in
                                if let k = item { cell(k) } else { Color.clear.frame(height: 76) }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    TrackedLabel(text: "How kana work", color: Ink.ink)
                    Text("Each kana is one beat. The chart reads あいうえお across and かさたなはまやらわ down: every row is a consonant plus the five vowels.")
                        .font(Typo.ui(13)).fixedSize(horizontal: false, vertical: true)
                    Text("Dakuten ゛ voices a sound (か→が). Handakuten ゜ turns は into ぱ. Small ゃゅょ combine: き + ゃ = きゃ.")
                        .font(Typo.ui(13)).fixedSize(horizontal: false, vertical: true)
                    Text("Click a kana to hear it. Ink shows how well you know it.").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                    let cards = KanaData.items(script, group).map(Card.kana)
                    Button("Study as flashcards") { router.startStudy("\(script.ja) · \(group.en)", cards: SessionBuilder.deck(cards, store), store: store) }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 46))
                    Button("Quiz") { router.startQuiz("\(script.en) · \(group.en)", cards: cards, count: min(15, cards.count), store: store) }
                        .buttonStyle(InkButtonStyle(kind: .outline, height: 42))
                    Spacer()
                }
                .frame(width: 300)
            }
            .padding(30)
            StepFooter(lesson: lesson, step: .learn)
        }
    }

    private func cell(_ k: KanaItem) -> some View {
        let m = store.mastery(k.id)
        let on = lit == k.id
        return Button {
            Speech.shared.say(k.char)
            lit = k.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if lit == k.id { lit = nil } }
        } label: {
            VStack(spacing: 0) {
                Text(k.char).font(Typo.mincho(group == .yoon ? 28 : 34))
                Text(k.romaji).font(Typo.ui(11, .bold)).opacity(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .foregroundStyle(on ? Ink.onAkane : m == .mature ? Ink.onInk : Ink.ink)
            .background { ZStack { if on { Ink.akane } else if m == .mature { Ink.ink } else { Ink.card; if m != .new { Screentone(density: m.density * 0.6, spacing: 4).opacity(0.5) } } } }
            .overlay(Rectangle().strokeBorder(on ? Ink.akane : Ink.ink, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(k.char), \(k.romaji)")
    }
}
