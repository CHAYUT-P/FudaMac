import SwiftUI

// MARK: - Flashcards on Mac

struct MacStudyView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router
    @Bindable var session: StudySession

    var body: some View {
        ZStack {
            Ink.paper
            if session.isDone {
                MacSessionComplete(session: session)
            } else if let card = session.current {
                VStack(spacing: 14) {
                    topBar
                    progress
                    cardView(card)
                    controls
                }
                .padding(.horizontal, 32).padding(.vertical, 20)
            }
        }
        .onDisappear { Speech.shared.stop(); session.finish() }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { session.finish(); router.study = nil } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)) }
                .buttonStyle(.plain).keyboardShortcut(.escape, modifiers: []).accessibilityLabel("End session")
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title).font(Typo.mincho(18)).lineLimit(1)
                Text(session.direction.en).font(Typo.ui(12)).foregroundStyle(Ink.soft)
            }
            Spacer()
            Text(session.repeats > 0 ? "\(session.position) / \(session.total) · \(session.repeats) again" : "\(session.position) / \(session.total)")
                .font(Typo.ui(14, .heavy)).monospacedDigit()
            ReadingToggles()
        }
        .foregroundStyle(Ink.ink)
    }

    private var progress: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Ink.line)
                Rectangle().fill(Ink.ink).frame(width: g.size.width * CGFloat(session.seen) / CGFloat(max(1, session.total)))
            }
        }
        .frame(height: 5)
    }

    private func cardView(_ card: Card) -> some View {
        let dir = session.direction(for: card)
        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .topTrailing) {
                Ink.card
                HalftoneField(fade: .radial(UnitPoint(x: 1, y: 0), inner: 0.05, outer: 0.5), spacing: 6, maxRadius: 2).opacity(0.45)
            }
            if session.flipped {
                MacCardBack(card: card).padding(.horizontal, 30).padding(.top, 58).padding(.bottom, 24)
            } else {
                MacCardFront(card: card, direction: dir).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                Tag(text: card.badge)
                Spacer()
                Button { store.toggleStar(card.id) } label: { Text(store.isStarred(card.id) ? "★" : "☆").font(.system(size: 20)).foregroundStyle(Ink.akane) }
                    .buttonStyle(.plain).keyboardShortcut("s", modifiers: []).accessibilityLabel("Star")
                if session.flipped || dir == .recognition {
                    Button { Speech.shared.say(card.speech) } label: { Image(systemName: "speaker.wave.2").font(.system(size: 15, weight: .semibold)).frame(width: 34, height: 34).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2)) }
                        .buttonStyle(.plain).keyboardShortcut("p", modifiers: []).accessibilityLabel("Play audio")
                }
            }
            .padding(18)
        }
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
        .cropMarks()
        .padding(8)
        .contentShape(Rectangle())
        .onTapGesture { flip() }
        .id(card.id + String(session.reviews))
    }

    @ViewBuilder private var controls: some View {
        if session.flipped {
            HStack(spacing: 10) {
                ForEach(Grade.allCases, id: \.self) { g in
                    Button { grade(g) } label: {
                        HStack(spacing: 10) {
                            Kbd("\(g.rawValue + 1)")
                            Text(g.en).font(Typo.ui(16, .heavy))
                            Text(session.label(g)).font(Typo.ui(12, .bold)).opacity(0.75)
                        }
                    }
                    .buttonStyle(InkButtonStyle(kind: g == .again ? .akaneOutline : g == .good ? .ink : .outline, height: 56))
                    .keyboardShortcut(KeyEquivalent(Character(String(g.rawValue + 1))), modifiers: [])
                }
            }
        } else {
            HStack(spacing: 10) {
                Button { grade(.again) } label: { HStack { Kbd("←"); Text("Didn't know") } }
                    .buttonStyle(InkButtonStyle(kind: .akaneOutline, height: 56)).frame(width: 200)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button { flip() } label: { HStack { Text("Show answer · 答え"); Kbd("Space", light: true) } }
                    .buttonStyle(InkButtonStyle(kind: .ink, height: 56))
                    .keyboardShortcut(.space, modifiers: [])
                Button { grade(.good) } label: { HStack { Text("Knew it"); Kbd("→") } }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 56)).frame(width: 200)
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }
    }

    private func flip() {
        withAnimation(.easeInOut(duration: 0.2)) { session.flipped.toggle() }
        if session.flipped, store.settings.autoAudio, let c = session.current, c.kind != .grammar { Speech.shared.say(c.speech) }
    }

    private func grade(_ g: Grade) {
        withAnimation(.easeOut(duration: 0.15)) { session.grade(g) }
        if let next = session.current, store.settings.autoAudio, session.direction(for: next) == .recognition, next.kind == .vocab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Speech.shared.say(next.speech) }
        }
    }
}

struct MacCardFront: View {
    @Environment(ProgressStore.self) private var store
    let card: Card
    let direction: StudyDirection

    var body: some View {
        VStack(spacing: 14) {
            switch (card.payload, direction) {
            case (.vocab(let v), .production):
                Text(v.th).font(.system(size: 44, weight: .semibold)).multilineTextAlignment(.center)
                Text("What's the Japanese?").font(Typo.ui(14, .bold)).foregroundStyle(Ink.soft)
            case (.vocab, .listening), (.kana, .listening):
                Button { Speech.shared.say(card.speech) } label: {
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 50)).foregroundStyle(Ink.onAkane)
                        .frame(width: 140, height: 140).background(Circle().fill(Ink.akane))
                }
                .buttonStyle(.plain)
                .onAppear { Speech.shared.say(card.speech) }
                Text("聴 · Listen, then flip").font(Typo.ui(14, .bold)).foregroundStyle(Ink.soft)
            case (.vocab(let v), _):
                JPText(ja: v.word, kana: v.kana, size: v.word.count > 5 ? 90 : 130, bold: true, alignment: .center, romajiText: v.romaji)
            case (.kanji(let k), _):
                ZStack {
                    Path { p in p.move(to: CGPoint(x: 110, y: 0)); p.addLine(to: CGPoint(x: 110, y: 220)); p.move(to: CGPoint(x: 0, y: 110)); p.addLine(to: CGPoint(x: 220, y: 110)) }
                        .stroke(Ink.akane.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    Text(k.char).font(Typo.mincho(170))
                }
                .frame(width: 220, height: 220).overlay(Rectangle().strokeBorder(Ink.akane, lineWidth: 2))
            case (.grammar(let g), _):
                Text(g.pattern).font(Typo.mincho(g.pattern.count > 10 ? 44 : 70)).multilineTextAlignment(.center).minimumScaleFactor(0.5)
                if !g.examples.isEmpty {
                    JPText(ja: g.examples[0].ja, kana: g.examples[0].kana, size: 20, color: Ink.soft, highlight: LessonScripts.coreOf(g.pattern), alignment: .center, romajiText: g.examples[0].romaji)
                }
                Text("What does this pattern mean?").font(Typo.ui(14, .bold)).foregroundStyle(Ink.soft)
            case (.kana(let k), .production):
                Text(k.romaji).font(.system(size: 100, weight: .heavy, design: .rounded))
                Text("Which \(k.script.en.lowercased())?").font(Typo.ui(14, .bold)).foregroundStyle(Ink.soft)
            case (.kana(let k), _):
                Text(k.char).font(Typo.mincho(170))
            }
            Text("SPACE TO FLIP · めくる").font(.system(size: 11, weight: .bold)).tracking(1.6).foregroundStyle(Ink.soft).padding(.top, 20)
        }
        .foregroundStyle(Ink.ink)
        .padding(30)
    }
}

/// The detailed Mac card back: word, meaning, examples on the left;
/// conjugation, kanji breakdown and "also met in" on the right.
struct MacCardBack: View {
    @Environment(ProgressStore.self) private var store
    let card: Card

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            left.frame(maxWidth: .infinity, alignment: .topLeading)
            right.frame(width: 360, alignment: .topLeading)
        }
        .foregroundStyle(Ink.ink)
        .textSelection(.enabled)
    }

    @ViewBuilder private var left: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch card.payload {
            case .vocab(let v):
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.settings.showRomaji ? "\(v.kana) · \(v.romaji)" : v.kana).font(Typo.ui(17, .bold)).foregroundStyle(Ink.soft)
                    Text(v.word).font(Typo.mincho(70)).lineLimit(1).minimumScaleFactor(0.5)
                }
                rule
                Text(v.th).font(.system(size: 30, weight: .semibold))
                Spacer(minLength: 0)
                if !v.exJA.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        TrackedLabel(text: "例文 · Example", size: 10)
                        SentenceBlock(ja: v.exJA, kana: v.exKana, romaji: v.exRomaji, th: v.exTH, en: v.exEN, size: 22, highlight: mark(v.exJA, v.kanji))
                    }
                    .padding(.top, 10).overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
                }
            case .kanji(let k):
                Text(k.char).font(Typo.mincho(120))
                rule
                Text(k.th).font(.system(size: 30, weight: .semibold))
                Text(k.en).font(Typo.ui(16)).foregroundStyle(Ink.soft)
                Spacer(minLength: 0)
            case .grammar(let g):
                Text(g.pattern).font(Typo.mincho(44)).lineLimit(2).minimumScaleFactor(0.5)
                Text("\(g.th) · \(g.en)").font(.system(size: 22, weight: .semibold))
                MixedText(g.structure, size: 14, weight: .bold, color: Ink.onInk).padding(8).background(Ink.ink)
                rule
                MixedText(store.settings.showEnglish ? g.explainEN : g.explainTH, size: 14)
                Spacer(minLength: 0)
            case .kana(let k):
                Text(k.char).font(Typo.mincho(140))
                rule
                Text(k.romaji).font(.system(size: 54, weight: .heavy, design: .rounded))
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder private var right: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch card.payload {
            case .vocab(let v):
                if v.pos == "verb", let f = Conjugate.forms(v.kanji, kana: v.kana) {
                    VStack(alignment: .leading, spacing: 0) {
                        TrackedLabel(text: "活用 · Conjugation · Group \(f.group.rawValue)", size: 10).padding(.bottom, 6)
                        ForEach(f.rows, id: \.0) { r in
                            HStack {
                                Text(r.0).font(Typo.ui(12, .heavy)).frame(width: 96, alignment: .leading)
                                Text(r.1).font(Typo.mincho(17))
                                Spacer()
                                Text(r.2).font(Typo.ui(11)).foregroundStyle(Ink.soft)
                            }
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
                        }
                    }
                    .inkBox(width: 1.5)
                }
                kanjiBreakdown(v.kanji)
                alsoMet(v.kanji.replacingOccurrences(of: "〜", with: ""))
            case .kanji(let k):
                VStack(alignment: .leading, spacing: 6) {
                    TrackedLabel(text: "Readings · \(k.strokes) strokes", size: 10)
                    Text("音  \(k.on.isEmpty ? "—" : k.on)").font(Typo.ui(16, .bold))
                    Text("訓  \(k.kun.isEmpty ? "—" : k.kun)").font(Typo.ui(16, .bold))
                }
                VStack(alignment: .leading, spacing: 0) {
                    TrackedLabel(text: "言葉 · Words with \(k.char)", size: 10).padding(.bottom, 6)
                    ForEach(k.examples, id: \.w) { e in
                        HStack { Text(e.w).font(Typo.mincho(20)); Text(e.r).font(Typo.ui(12)).foregroundStyle(Ink.soft); Spacer(); Text(e.m).font(Typo.ui(13)) }
                            .padding(.vertical, 6).overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
                    }
                }
                let words = DB.shared.vocab.filter { $0.kanji.contains(k.char) }.prefix(5)
                if !words.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        TrackedLabel(text: "In your decks", size: 10)
                        Text(words.map { "\($0.kanji)（\($0.kana)）" }.joined(separator: "  ")).font(Typo.mincho(14, bold: false))
                    }
                }
            case .grammar(let g):
                VStack(alignment: .leading, spacing: 8) {
                    TrackedLabel(text: "例文 · Examples", size: 10)
                    ForEach(Array(g.examples.prefix(3).enumerated()), id: \.offset) { _, e in
                        SentenceBlock(ja: e.ja, kana: e.kana, romaji: e.romaji, th: e.th, en: e.en, size: 16)
                            .padding(.vertical, 4)
                    }
                }
                if let l = Course.shared.lesson(teaching: g.key) {
                    Text("道 Taught in Lesson \(l.n) · \(l.ja)").font(Typo.ui(12, .heavy)).padding(8).inkBox(width: 1.5)
                }
            case .kana(let k):
                Text(k.script == .hira ? "Katakana: \(KanaData.toKatakana(k.char))" : "Hiragana partner shown in the chart").font(Typo.ui(14))
            }
        }
    }

    private var rule: some View {
        HStack(spacing: 8) { Rectangle().fill(Ink.akane).frame(width: 10, height: 10); Rectangle().fill(Ink.ink).frame(height: 2) }
    }

    @ViewBuilder private func kanjiBreakdown(_ word: String) -> some View {
        let ks = word.compactMap { ch -> KanjiItem? in DB.shared.kanji.first { $0.char == String(ch) } }
        if !ks.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                TrackedLabel(text: "漢字 · Kanji in this word", size: 10)
                ForEach(ks) { k in
                    HStack(spacing: 10) {
                        Text(k.char).font(Typo.mincho(28)).frame(width: 46, height: 46).overlay(Rectangle().strokeBorder(Ink.akane, lineWidth: 1.5))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(k.th) · \(k.en)").font(Typo.ui(13, .bold)).lineLimit(1)
                            Text("音 \(k.on)  訓 \(k.kun)").font(Typo.ui(11)).foregroundStyle(Ink.soft).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func alsoMet(_ word: String) -> some View {
        let talks = Talk.scenes.filter { s in s.spoken.contains { $0.ja.contains(word) } }.prefix(2).map { "話 \($0.title)" }
        let stories = Course.shared.stories.filter { s in s.sentences.contains { $0.ja.contains(word) } }.prefix(2).map { "読 \($0.jaTitle)" }
        let lessons = Course.shared.lessons.filter { l in l.sections.contains { $0.ids.contains { $0.hasPrefix(word + "_") } } }.prefix(1).map { "道 Lesson \($0.n)" }
        let all = lessons + talks + stories
        if !all.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                TrackedLabel(text: "Also met in", size: 10)
                Flow(spacing: 6) {
                    ForEach(all, id: \.self) { Text($0).font(Typo.ui(12, .bold)).padding(.horizontal, 8).padding(.vertical, 4).overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5)) }
                }
            }
        }
    }

    private func mark(_ s: String, _ word: String) -> String? {
        var stem = word.replacingOccurrences(of: "〜", with: "")
        while let last = stem.last, stem.count > 1, !Furigana.isKanji(last), stem.contains(where: Furigana.isKanji) { stem.removeLast() }
        guard let r = s.range(of: stem) else { return nil }
        var end = r.upperBound, n = 0
        while end < s.endIndex, n < 4, s[end].unicodeScalars.allSatisfy({ (0x3041...0x3096).contains($0.value) }) { end = s.index(after: end); n += 1 }
        return String(s[r.lowerBound..<end])
    }
}

struct MacSessionComplete: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router
    let session: StudySession
    @State private var stamped = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                FocusLines(count: 80).frame(width: 520, height: 300)
                    .mask(RadialGradient(colors: [.clear, .black, .black, .clear], center: .center, startRadius: 70, endRadius: 250))
                Circle().fill(Ink.paper).frame(width: 190)
                HankoSeal(text: "済", size: 140).scaleEffect(stamped ? 1 : 1.8).opacity(stamped ? 1 : 0)
            }
            Text("お疲れさま").font(Typo.mincho(34))
            TrackedLabel(text: "Session complete · \(session.title)")
            HStack(spacing: 0) {
                stat("\(Int((session.accuracy * 100).rounded()))%", "\(session.correct) of \(session.seen) recalled")
                Rectangle().fill(Ink.ink).frame(width: 2)
                stat("+\(session.learnedNew)", "new cards")
                Rectangle().fill(Ink.ink).frame(width: 2)
                stat(String(format: "%d:%02d", Int(session.duration) / 60, Int(session.duration) % 60), "time")
            }
            .fixedSize().inkBox()
            HStack(spacing: 10) {
                if !session.missed.isEmpty {
                    Button("Review \(session.missed.count) missed") {
                        router.study = StudySession(title: "Missed cards", cards: session.missed, direction: session.direction, store: store)
                    }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 48)).frame(width: 220)
                }
                Button("Done") { router.study = nil }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 48)).frame(width: 160)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.35, bounce: 0.35).delay(0.1)) { stamped = true }; Haptic.success() }
    }

    private func stat(_ big: String, _ small: String) -> some View {
        VStack(spacing: 2) { Text(big).font(Typo.mincho(28)); Text(small).font(Typo.ui(11, .bold)).foregroundStyle(Ink.soft) }
            .frame(width: 170).padding(.vertical, 14)
    }
}

// MARK: - Quiz

struct MacQuizView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    @Bindable var session: QuizSession
    let lessonTest: Int?
    @State private var recorded = false

    var body: some View {
        ZStack {
            Ink.paper
            if session.isDone { result } else if let q = session.current { question(q).id(q.id) }
        }
        .onDisappear { Speech.shared.stop() }
    }

    private func question(_ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { router.quiz = nil } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)) }
                    .buttonStyle(.plain).keyboardShortcut(.escape, modifiers: []).accessibilityLabel("End quiz")
                Text(session.title).font(Typo.mincho(18))
                Spacer()
                Text("\(session.index + 1) / \(session.questions.count)").font(Typo.ui(14, .heavy))
                Text("\(session.score)").font(Typo.mincho(20)).foregroundStyle(Ink.akane).frame(width: 40)
            }
            HStack(spacing: 3) {
                ForEach(0..<session.questions.count, id: \.self) { i in
                    Rectangle().fill(i < session.results.count ? (session.results[i] ? Ink.ink : Ink.akane) : Ink.line).frame(height: 5)
                }
            }
            TrackedLabel(text: q.instruction, color: Ink.ink, size: 12)
            ZStack {
                Ink.card
                HalftoneField(fade: .radial(UnitPoint(x: 1, y: 0), inner: 0.05, outer: 0.5), spacing: 6, maxRadius: 2).opacity(0.4)
                VStack(spacing: 10) {
                    if let audio = q.audio {
                        Button { Speech.shared.say(audio) } label: {
                            Image(systemName: "speaker.wave.3.fill").font(.system(size: 40)).foregroundStyle(Ink.onAkane)
                                .frame(width: 110, height: 110).background(Circle().fill(Ink.akane))
                        }
                        .buttonStyle(.plain).keyboardShortcut("p", modifiers: [])
                        .onAppear { Speech.shared.say(audio) }
                    } else {
                        Group {
                            // Reading questions keep furigana off — it would give the answer away.
                            if q.kind == .reading || q.kind == .kanjiReading || !q.promptIsJapanese {
                                Text(q.prompt).font(q.promptIsJapanese ? Typo.mincho(q.prompt.count > 12 ? 30 : 60) : .system(size: 36, weight: .semibold))
                                    .multilineTextAlignment(.center).minimumScaleFactor(0.5)
                            } else {
                                MixedText(q.prompt, size: q.prompt.count > 12 ? 28 : 54, weight: .bold, center: true)
                            }
                        }
                        .textSelection(.enabled)
                    }
                    if !q.caption.isEmpty, session.picked != nil || q.kind == .grammarExercise || q.kind == .grammarMeaning {
                        MixedText(q.caption, size: 14, color: Ink.soft, center: true)
                    }
                }
                .padding(24)
            }
            .frame(height: 230)
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(q.options.indices, id: \.self) { i in
                    let picked = session.picked
                    let st: (Color, Color, Color, Double) = picked == nil ? (Ink.card, Ink.ink, Ink.ink, 1) : i == q.answer ? (Ink.ink, Ink.onInk, Ink.ink, 1) : i == picked ? (Ink.akane, Ink.onAkane, Ink.akane, 1) : (Ink.card, Ink.ink, Ink.ink, 0.45)
                    Button { session.pick(i) } label: {
                        HStack(spacing: 12) {
                            Kbd("\(i + 1)")
                            Text(q.options[i]).font(q.optionsJapanese ? Typo.mincho(21) : Typo.ui(16, .semibold)).multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 16).frame(minHeight: 60)
                        .foregroundStyle(st.1).background(st.0)
                        .overlay(Rectangle().strokeBorder(st.2, lineWidth: 2)).opacity(st.3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(picked != nil)
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [])
                }
            }
            if session.picked != nil {
                HStack(alignment: .top) {
                    MixedText(q.explanation, size: 13, color: Ink.soft)
                    Spacer()
                    Button { session.next() } label: { HStack { Text(session.index + 1 < session.questions.count ? "Next" : "See results"); Kbd("↩", light: true) } }
                        .buttonStyle(InkButtonStyle(kind: .ink, height: 46)).frame(width: 180)
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
            Spacer(minLength: 0)
        }
        .padding(30)
    }

    private var result: some View {
        let pct = session.questions.isEmpty ? 0 : Int((Double(session.score) / Double(session.questions.count) * 100).rounded())
        return VStack(spacing: 18) {
            ZStack {
                FocusLines(count: 70).frame(width: 480, height: 280)
                    .mask(RadialGradient(colors: [.clear, .black, .black, .clear], center: .center, startRadius: 70, endRadius: 240))
                Circle().fill(Ink.paper).frame(width: 180)
                if pct >= 80 || (lessonTest != nil && pct >= 70) {
                    VStack(spacing: 0) { Text("合"); Text("格") }.font(Typo.mincho(50)).foregroundStyle(Ink.akane)
                        .frame(width: 150, height: 150)
                        .overlay(Circle().strokeBorder(Ink.akane, lineWidth: 5))
                        .overlay(Circle().strokeBorder(Ink.akane, lineWidth: 1.5).padding(9))
                        .rotationEffect(.degrees(8))
                } else {
                    Text("\(session.score)/\(session.questions.count)").font(Typo.mincho(54))
                }
            }
            Text(pct >= 80 ? "よくできました" : pct >= 50 ? "もう少し" : "がんばろう").font(Typo.mincho(30))
            Text("\(session.score) of \(session.questions.count) correct · \(pct)%" + (lessonTest != nil ? (pct >= 70 ? " · lesson stamped 済" : " · 70% stamps the lesson") : ""))
                .font(Typo.ui(15)).foregroundStyle(Ink.soft)
            if !session.missed.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    TrackedLabel(text: "間違い · To review", color: Ink.akane).padding(.bottom, 4)
                    ForEach(session.missed.prefix(5)) { MacCardRow(card: $0) }
                }
                .frame(maxWidth: 700)
            }
            HStack(spacing: 10) {
                if !session.missed.isEmpty {
                    Button("Study mistakes") {
                        let missed = session.missed
                        router.quiz = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.startStudy("Quiz mistakes", cards: missed, store: store) }
                    }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 48)).frame(width: 200)
                }
                Button("Done") { router.quiz = nil }.buttonStyle(InkButtonStyle(kind: .akane, height: 48)).frame(width: 160)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(30)
        .onAppear {
            guard !recorded, let n = lessonTest else { return }
            recorded = true
            course.recordTest(n, score: pct)
        }
    }
}
