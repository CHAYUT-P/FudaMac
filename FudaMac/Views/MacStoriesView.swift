import SwiftUI

struct MacStoriesView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router

    var body: some View {
        let stories = Course.shared.stories
        let cur = stories.first { $0.key == router.storyKey } ?? stories.first
        let shelves = ["短編 · Short", "長編 · Longer", "昔話 · Folk tales", "N4"]
        HStack(spacing: 0) {
            ListColumn(width: 280) {
                VStack(alignment: .leading, spacing: 4) {
                    TrackedLabel(text: "読 · Stories")
                    Text("Graded reading").font(Typo.mincho(26))
                    Text("\(stories.count) stories · \(stories.filter { course.stories.contains($0.key) }.count) read").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                }
                .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 4)
                ForEach(shelves, id: \.self) { shelf in
                    ListGroupLabel(text: shelf.uppercased())
                    ForEach(stories.filter { $0.shelf == shelf }) { s in
                        ListRow(title: s.jaTitle, subtitle: "\(s.englishTitle) · \(s.sentences.count) sentences",
                                trailing: course.stories.contains(s.key) ? "済" : "", trailingAccent: true, selected: s.key == cur?.key) {
                            router.storyKey = s.key
                        }
                    }
                }
            }
            if let s = cur {
                StoryReader(story: s) { score in course.recordStory(s.key, score: score) }.id(s.key)
            }
        }
    }
}

/// Reader for one graded story: horizontal or vertical (縦書き) text, sentence
/// focus with translation and words, read-aloud, and a short comprehension quiz.
struct StoryReader: View {
    @Environment(ProgressStore.self) private var store
    let story: GradedStory
    var onFinish: (Int) -> Void

    @State private var sel = 0
    @AppStorage("storyVertical") private var vertical = false
    @State private var reading = false
    @State private var quiz: [StoryQuestion]?
    @State private var qi = 0
    @State private var picked: Int?
    @State private var score = 0

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        TrackedLabel(text: "\(story.shelf) · \(story.level.title)")
                        Text(story.jaTitle).font(Typo.mincho(32)).lineLimit(1).fixedSize()
                        Text("\(story.englishTitle) · \(story.sentences.count) sentences · about \(story.minutes) min").font(Typo.ui(13)).foregroundStyle(Ink.soft).lineLimit(1)
                    }
                    .layoutPriority(1)
                    Spacer()
                    ReadingToggles()
                    Segmented(options: [(false, "横書き"), (true, "縦書き")], selection: $vertical, height: 34)
                        .help("Horizontal or vertical writing")
                }
                ZStack(alignment: .topTrailing) {
                    Ink.card
                    if vertical { verticalPage } else { horizontalPage }
                    if !vertical { StampBadge(text: "読", size: 50).padding(18) }
                }
                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
                HStack(spacing: 12) {
                    Button { reading ? stopReading() : readAloud(from: sel) } label: { HStack { Image(systemName: reading ? "stop.fill" : "play.fill"); Text(reading ? "Stop" : "Read aloud") } }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 40)).frame(width: 150)
                    Button { sel = max(0, sel - 1) } label: { Text("↑ Prev") }.buttonStyle(InkButtonStyle(kind: .outline, height: 40)).frame(width: 90)
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button { sel = min(story.sentences.count - 1, sel + 1) } label: { Text("↓ Next") }.buttonStyle(InkButtonStyle(kind: .outline, height: 40)).frame(width: 90)
                        .keyboardShortcut(.downArrow, modifiers: [])
                    Spacer()
                    Text("Click a sentence · ↑ ↓ to move · P plays it").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                    Button("Play sentence") { Speech.shared.say(story.sentences[sel].kana) }
                        .keyboardShortcut("p", modifiers: []).opacity(0).frame(width: 1).accessibilityHidden(true)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            side
        }
        .onDisappear { stopReading() }
    }

    // MARK: Pages

    private var paragraphs: [[Int]] {
        var out: [[Int]] = [[]]
        let breaks = Set(story.paragraphAfter)
        for i in story.sentences.indices {
            out[out.count - 1].append(i)
            if breaks.contains(i) || (breaks.isEmpty && (i + 1) % 3 == 0) { out.append([]) }
        }
        return out.filter { !$0.isEmpty }
    }

    private var horizontalPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(paragraphs, id: \.self) { para in
                    Flow(spacing: 4) {
                        ForEach(para, id: \.self) { i in
                            let s = story.sentences[i]
                            Button { sel = i; Speech.shared.say(s.kana) } label: {
                                JPText(ja: s.ja, kana: s.kana, size: 24, romajiText: s.romaji)
                                .padding(.horizontal, 3).padding(.vertical, 2)
                                .background(i == sel ? Ink.akane.opacity(0.12) : .clear)
                                .overlay(alignment: .bottom) { Rectangle().fill(i == sel ? Ink.akane : .clear).frame(height: 3) }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 50).padding(.vertical, 44)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    /// Vertical writing: columns top→bottom, read right→left.
    private var verticalPage: some View {
        GeometryReader { geo in
            let fontSize: CGFloat = 25
            let cell = fontSize * 1.18
            let perColumn = max(6, Int((geo.size.height - 90) / cell))
            let columns = verticalColumns(perColumn: perColumn)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: fontSize * 0.9) {
                    ForEach(columns.indices.reversed(), id: \.self) { c in
                        VStack(spacing: 0) {
                            ForEach(columns[c].indices, id: \.self) { k in
                                let item = columns[c][k]
                                Text(item.char).font(Typo.mincho(fontSize, bold: false))
                                    .frame(width: cell, height: cell)
                                    .background(item.sentence == sel ? Ink.akane.opacity(0.12) : .clear)
                                    .overlay(alignment: .trailing) { Rectangle().fill(item.sentence == sel ? Ink.akane : .clear).frame(width: 3) }
                                    .onTapGesture { sel = item.sentence; Speech.shared.say(story.sentences[item.sentence].kana) }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .padding(.horizontal, 40).padding(.vertical, 36)
                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topTrailing)
            }
            .defaultScrollAnchor(.trailing)
        }
        .foregroundStyle(Ink.ink)
    }

    private struct VChar { let char: String; let sentence: Int }

    private func verticalColumns(perColumn: Int) -> [[VChar]] {
        let map: [Character: String] = ["。": "︒", "、": "︑", "ー": "｜", "「": "﹁", "」": "﹂", "（": "︵", "）": "︶", "…": "︙", "〜": "≀", "・": "・"]
        var cols: [[VChar]] = [[]]
        for para in paragraphs {
            for i in para {
                for ch in story.sentences[i].ja {
                    if cols[cols.count - 1].count >= perColumn { cols.append([]) }
                    cols[cols.count - 1].append(VChar(char: map[ch] ?? String(ch), sentence: i))
                }
            }
            cols.append([])
        }
        return cols.filter { !$0.isEmpty }
    }

    // MARK: Side

    private var side: some View {
        let s = story.sentences[min(sel, story.sentences.count - 1)]
        let words = DB.shared.vocab.filter { $0.kanji.count >= 2 && !$0.kanji.contains("〜") && s.ja.contains($0.kanji) }.prefix(6)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { TrackedLabel(text: "Sentence \(sel + 1) / \(story.sentences.count)", color: Ink.akane, size: 10); Spacer(); SpeakIcon(text: s.kana, size: 28) }
                    SentenceBlock(ja: s.ja, kana: s.kana, romaji: s.romaji, th: s.th, en: s.en, size: 21)
                }
                .padding(14).inkBox()
                if !words.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        TrackedLabel(text: "言葉 · Words", color: Ink.ink, size: 10).padding(.bottom, 6)
                        ForEach(Array(words)) { w in
                            HStack {
                                Text(w.kanji).font(Typo.mincho(16)).frame(width: 84, alignment: .leading)
                                Text(w.th).font(Typo.ui(13)).lineLimit(1)
                                Spacer()
                                Circle().fill(store.mastery("v:" + w.id) >= .young ? Ink.ink : .clear).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 1.5)).frame(width: 9, height: 9)
                            }
                            .padding(.vertical, 6).overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
                        }
                    }
                }
                if !story.summaryTH.isEmpty {
                    MixedText(story.summaryTH, size: 12, color: Ink.soft)
                }
                quizPanel
            }
            .padding(22)
        }
        .frame(width: 340)
        .background(Ink.chip.opacity(0.6))
        .overlay(alignment: .leading) { Rectangle().fill(Ink.ink).frame(width: 2) }
    }

    @ViewBuilder private var quizPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TrackedLabel(text: "After reading · 3 questions", color: Color(hex: 0xE5605B), size: 10)
            if let quiz {
                if qi < quiz.count {
                    let q = quiz[qi]
                    Text("Which sentence means:").font(Typo.ui(12)).opacity(0.8)
                    Text("“\(store.settings.showEnglish ? q.en : q.th)”").font(Typo.ui(14, .bold))
                    ForEach(q.options.indices, id: \.self) { i in
                        let st: (Color, Color) = picked == nil ? (.clear, Ink.onInk) : i == q.answer ? (Ink.onInk, Ink.ink) : i == picked ? (Ink.akane, Ink.onAkane) : (.clear, Ink.onInk.opacity(0.4))
                        Button {
                            guard picked == nil else { return }
                            picked = i; if i == q.answer { score += 1 }
                        } label: {
                            Text(q.options[i]).font(Typo.mincho(14, bold: false)).multilineTextAlignment(.leading)
                                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(st.1).background(st.0)
                                .overlay(Rectangle().strokeBorder(Ink.onInk.opacity(0.7), lineWidth: 1.5)).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if picked != nil {
                        Button("Next →") { qi += 1; picked = nil; if qi >= quiz.count { onFinish(Int(Double(score) / Double(quiz.count) * 100)) } }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 36))
                    }
                } else {
                    HStack(spacing: 10) {
                        StampBadge(text: "済", size: 40)
                        Text("\(score) / \(quiz.count) · story read").font(Typo.ui(14, .heavy))
                    }
                    Button("Try again") { self.quiz = StoryQuestion.make(story); qi = 0; score = 0; picked = nil }
                        .buttonStyle(InkButtonStyle(kind: .outline, height: 34))
                }
            } else {
                Text("Check you understood. Passing stamps the story 済.").font(Typo.ui(12)).opacity(0.85)
                Button("Start the questions") { quiz = StoryQuestion.make(story); qi = 0; score = 0; picked = nil }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 38))
            }
        }
        .foregroundStyle(Ink.onInk)
        .padding(14)
        .background(Ink.ink)
    }

    // MARK: Read aloud

    private func readAloud(from i: Int) {
        guard i < story.sentences.count else { reading = false; return }
        reading = true
        sel = i
        Speech.shared.say(story.sentences[i].kana) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { if reading { readAloud(from: i + 1) } }
        }
    }

    private func stopReading() { reading = false; Speech.shared.stop() }
}

struct StoryQuestion {
    let en: String
    let th: String
    let options: [String]
    let answer: Int

    static func make(_ story: GradedStory) -> [StoryQuestion] {
        let s = story.sentences
        guard s.count >= 3 else { return [] }
        return Array(s.indices.shuffled().prefix(3)).map { i in
            var wrong = s.indices.filter { $0 != i }.shuffled().prefix(2).map { s[$0].ja }
            let at = Int.random(in: 0...wrong.count)
            wrong.insert(s[i].ja, at: at)
            return StoryQuestion(en: s[i].en, th: s[i].th, options: wrong, answer: at)
        }
    }
}
