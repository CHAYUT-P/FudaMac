import SwiftUI

struct MacTodayView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router

    var body: some View {
        let due = store.dueCount()
        let level = store.settings.level
        let unseen = DB.shared.path(level).lazy.filter { store.state($0.id) == nil }.prefix(store.settings.newPerDay).count
        let newToday = min(store.newRemainingToday, unseen)
        let mins = max(1, Int((Double(min(due, 200)) * 8 + Double(newToday) * 20) / 60))

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateLine).font(Typo.ui(12, .bold)).tracking(1.8).foregroundStyle(Ink.soft)
                        Text(greeting).font(Typo.mincho(36)).foregroundStyle(Ink.ink)
                    }
                    Spacer()
                    ReadingToggles()
                }

                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 20) {
                        courseCard
                        HStack(alignment: .top, spacing: 20) {
                            reviewCard(due: due, new: newToday, mins: mins)
                            practiceCard
                        }
                        HStack(alignment: .top, spacing: 20) {
                            talkCard
                            storyCard
                            essentialCard
                        }
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 20) {
                        streakCard
                        levelCard(level)
                        forecastCard
                    }
                    .frame(width: 330)
                }
            }
            .padding(.horizontal, 36).padding(.vertical, 28)
        }
        .background(alignment: .top) {
            HalftoneField(fade: .up, spacing: 6, maxRadius: 1.6).frame(height: 120).opacity(0.3)
        }
    }

    private var dateLine: String {
        let ja = ["日", "月", "火", "水", "木", "金", "土"][Calendar.current.component(.weekday, from: .now) - 1] + "曜日"
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEEE d MMMM"
        return "\(ja) · \(f.string(from: .now).uppercased())"
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 11 ? "おはよう — today's plan" : h < 18 ? "こんにちは — today's plan" : "こんばんは — today's plan"
    }

    // MARK: Course

    @ViewBuilder private var courseCard: some View {
        if let l = course.currentLesson {
            let next = course.nextStep(l.n)
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    TrackedLabel(text: "Lesson", color: Ink.onInk.opacity(0.7), size: 10)
                    Text(l.numeral).font(Typo.mincho(l.n > 10 ? 54 : 88)).minimumScaleFactor(0.5).lineLimit(1)
                    Text("of \(Course.shared.lessons.count) · 第\(l.part.numeral)部").font(Typo.ui(12, .bold)).opacity(0.7)
                }
                .foregroundStyle(Ink.onInk)
                .frame(width: 180)
                .frame(maxHeight: .infinity)
                .background(ZStack { Ink.ink; HalftoneField(fade: .down, spacing: 6, maxRadius: 1.6, color: Ink.onInk).opacity(0.25) })

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            TrackedLabel(text: "Continue the course", color: Ink.akane)
                            MixedText("\(l.ja) — \(l.en)", size: 26, weight: .bold)
                            MixedText(summary(l), size: 13, color: Ink.soft)
                        }
                        Spacer()
                        Text("\(course.doneCount(l.n)) / \(course.stepCount(l.n)) steps").font(Typo.ui(13, .heavy))
                    }
                    HStack(spacing: 6) {
                        ForEach(LessonStep.steps(for: l.n)) { st in
                            let done = course.isDone(l.n, st), now = st == next
                            Button { router.openLesson(l.n, step: st) } label: {
                                VStack(spacing: 1) {
                                    Text(st.ja(l.n)).font(Typo.mincho(16))
                                    Text((done ? "✓ " : "") + st.en(l.n).uppercased()).font(.system(size: 9, weight: .heavy))
                                }
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .foregroundStyle(done ? Ink.onInk : now ? Ink.akane : Ink.soft)
                                .background(done ? Ink.ink : .clear)
                                .background { if now { Screentone(density: 0.25, spacing: 4, color: Ink.akane) } }
                                .overlay(Rectangle().strokeBorder(done ? Ink.ink : now ? Ink.akane : Ink.line, lineWidth: now ? 2 : 1.5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 10) {
                        Button { router.openLesson(l.n, step: next) } label: { Text("Continue · \(next.ja) \(next.en) →").padding(.horizontal, 20) }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 46)).fixedSize()
                            .keyboardShortcut(.return, modifiers: .command)
                        Button { router.section = .course; router.lessonN = nil } label: { Text("Course map").padding(.horizontal, 16) }
                            .buttonStyle(InkButtonStyle(kind: .outline, height: 46)).fixedSize()
                    }
                }
                .padding(22)
            }
            .fixedSize(horizontal: false, vertical: true)
            .inkBox()
        }
    }

    private func summary(_ l: CourseLesson) -> String {
        var parts: [String] = []
        if l.isKana { parts.append("\(KanaData.all.count) kana") }
        if !l.grammar.isEmpty { parts.append("\(l.grammar.count) grammar points") }
        let w = l.sections.reduce(0) { $0 + $1.ids.count }
        if w > 0 { parts.append("\(w) words") }
        if !l.kanji.isEmpty { parts.append(l.kanji.joined()) }
        let talks = l.dialogues.compactMap { Course.shared.dialogue($0)?.jaTitle }
        if !talks.isEmpty { parts.append("話 " + talks.joined(separator: " · ")) }
        return parts.joined(separator: " · ")
    }

    // MARK: Review & practice

    private func reviewCard(due: Int, new: Int, mins: Int) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                TrackedLabel(text: "今日の復習 · Review", color: Ink.ink)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(due)").font(Typo.mincho(66)).lineLimit(1).minimumScaleFactor(0.4).contentTransition(.numericText())
                    Text("cards\ndue").font(Typo.ui(14, .heavy))
                }
                Text(new > 0 ? "+\(new) new · about \(mins) min" : due > 0 ? "about \(mins) min" : "All caught up")
                    .font(Typo.ui(13))
            }
            Spacer()
            Button {
                router.startStudy("Today · 今日", cards: SessionBuilder.today(store), store: store)
            } label: { HStack(spacing: 8) { Text("Start review"); Kbd("Space", light: true) }.padding(.horizontal, 16) }
                .buttonStyle(InkButtonStyle(kind: .ink, height: 46)).fixedSize()
                .keyboardShortcut(.space, modifiers: [])
                .disabled(due + new == 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(alignment: .topTrailing) { HalftoneSun(size: 200).offset(x: 60, y: -70).opacity(0.85).clipped() }
        .clipped()
        .inkBox()
    }

    private var practiceCard: some View {
        let seen = store.states.keys.compactMap { DB.shared.card($0) }
        let pool = seen.count >= 8 ? seen : Array(DB.shared.path(store.settings.level).prefix(60))
        let weak = store.weakCards
        return VStack(alignment: .leading, spacing: 10) {
            TrackedLabel(text: "Quick practice", color: Ink.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                Button("試 Mixed quiz") { router.startQuiz("Mixed quiz", cards: pool, count: 15, store: store) }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 38))
                Button("聴 Listening") { router.startQuiz("Listening", cards: pool.filter { $0.kind == .vocab }.count >= 8 ? pool.filter { $0.kind == .vocab } : DB.shared.vocab(store.settings.level), mode: .listening, store: store) }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 38))
                Button("弱 Weak · \(weak.count)") { router.startStudy("Weak cards", cards: Array(weak.prefix(20)), store: store) }
                    .buttonStyle(InkButtonStyle(kind: weak.isEmpty ? .outline : .akaneOutline, height: 38))
                    .disabled(weak.isEmpty)
                Button("文 Grammar") { router.startQuiz("Grammar check", cards: DB.shared.grammar(store.settings.level), count: 10, store: store) }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 38))
            }
            .font(Typo.ui(13, .heavy))
        }
        .padding(18)
        .frame(width: 330)
        .inkBox()
    }

    // MARK: Talk / story / essential

    private var talkCard: some View {
        // The current lesson's conversation first (friend, then polite), else a real-life scene.
        let lessonTalk = course.currentLesson.flatMap { l in Talk.lessonPair(l.n).first { !course.talks.contains($0.id) } ?? Talk.lessonPair(l.n).first }
        let scene = lessonTalk ?? Talk.situations.first { !course.talks.contains($0.id) } ?? Talk.scenes.first
        return Button { router.talkID = scene?.id; router.section = .talk } label: {
            VStack(alignment: .leading, spacing: 8) {
                TrackedLabel(text: "話 · Conversation")
                Text(scene?.title ?? "").font(Typo.mincho(22))
                Text(scene.map { $0.lesson != nil ? "Lesson \($0.lesson!) · \($0.registerJA) \($0.registerEN)" : $0.en } ?? "").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                ForEach(Array((scene?.spoken.prefix(2) ?? []).enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(line.you ? "あなた" : (line.speaker.isEmpty ? "—" : line.speaker))
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .foregroundStyle(line.you ? Ink.onAkane : Ink.ink)
                            .background(line.you ? Ink.akane : Ink.chip)
                        Text(line.ja).font(Typo.mincho(14, bold: false)).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text("Role-play →").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .inkBox()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var storyCard: some View {
        let story = Course.shared.stories.first { !course.stories.contains($0.key) && $0.level == store.settings.level } ?? Course.shared.stories.first
        return Button { router.storyKey = story?.key; router.section = .read } label: {
            VStack(alignment: .leading, spacing: 8) {
                TrackedLabel(text: "読 · Story")
                Text(story?.jaTitle ?? "").font(Typo.mincho(22))
                Text("\(story?.englishTitle ?? "") · \(story?.sentences.count ?? 0) sentences").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                Text(story?.sentences.prefix(2).map(\.ja).joined() ?? "").font(Typo.mincho(14, bold: false)).lineLimit(2)
                Spacer(minLength: 0)
                Text("Read →").font(Typo.ui(13, .heavy)).foregroundStyle(Ink.akane)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .inkBox()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var essentialCard: some View {
        let ch = Essentials.chapters.first { !course.essentials.contains($0.id) } ?? Essentials.chapters[0]
        return Button { router.essentialID = ch.id; router.section = .essentials } label: {
            VStack(alignment: .leading, spacing: 8) {
                TrackedLabel(text: "基 · Essential", color: Ink.onInk.opacity(0.7))
                Text("\(ch.ja) — \(ch.en)").font(Typo.mincho(20)).lineLimit(2)
                MixedText(ch.intro, size: 12, color: Ink.onInk).opacity(0.85).frame(maxHeight: 90, alignment: .top).clipped()
                Spacer(minLength: 0)
                Text("Open Essentials →").font(Typo.ui(13, .heavy)).foregroundStyle(Color(hex: 0xE5605B))
            }
            .foregroundStyle(Ink.onInk)
            .padding(16).frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .background(Ink.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Right column

    private var streakCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let wd = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -wd, to: today)!
        let mins = (0..<7).map { store.stat(on: cal.date(byAdding: .day, value: $0, to: monday)!).seconds / 60 }
        let peak = max(20, mins.max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                (Text("連続 ") + Text("\(store.streak)日").foregroundColor(Ink.akane) + Text(" streak")).font(Typo.ui(15, .heavy))
                Spacer()
                OutlineStamp(text: "Best \(max(store.bestStreak, store.streak))", size: 11)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let d = cal.date(byAdding: .day, value: i, to: monday)!
                    VStack(spacing: 3) {
                        Text(mins[i] > 0 ? "\(mins[i])" : "").font(Typo.ui(10, .bold))
                        Rectangle().fill(d == today ? Ink.akane : mins[i] > 0 ? Ink.ink : .clear)
                            .frame(height: max(4, 56 * CGFloat(mins[i]) / CGFloat(peak)))
                            .overlay(Rectangle().strokeBorder(mins[i] > 0 ? .clear : Ink.line, style: StrokeStyle(lineWidth: 1.5, dash: [3])))
                        Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(Typo.ui(10, .bold)).foregroundStyle(Ink.soft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90, alignment: .bottom)
            Text("Minutes studied this week").font(Typo.ui(12)).foregroundStyle(Ink.soft)
        }
        .padding(18).inkBox()
    }

    private func levelCard(_ level: Level) -> some View {
        let rows: [(String, String, [Card])] = [("語彙", "Vocab", DB.shared.vocab(level)), ("漢字", "Kanji", DB.shared.kanji(level)), ("文法", "Grammar", DB.shared.grammar(level))]
        let lessons = Course.shared.lessons(level)
        let passed = lessons.filter { course.passed($0.n) }.count
        let all = rows.flatMap(\.2)
        let pct = all.isEmpty ? 0 : Int(Double(all.filter { store.mastery($0.id) >= .young }.count) / Double(all.count) * 100)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TrackedLabel(text: "JLPT \(level.title)", color: Ink.ink)
                Spacer()
                Text("\(pct)%").font(Typo.mincho(30))
            }
            ForEach(rows, id: \.1) { ja, en, cards in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        (Text(ja).font(Typo.mincho(13)) + Text(" \(en)").font(Typo.ui(13, .heavy)))
                        Spacer()
                        Text("\(cards.filter { store.mastery($0.id) >= .young }.count) / \(cards.count)").font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft)
                    }
                    MacMasteryStrip(counts: store.counts(cards), height: 12)
                }
            }
            HStack {
                (Text("道").font(Typo.mincho(13)) + Text(" Lessons").font(Typo.ui(13, .heavy)))
                Spacer()
                Text("\(passed) / \(lessons.count) 済").font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft)
            }
        }
        .padding(18).inkBox()
    }

    private var forecastCard: some View {
        let cal = Calendar.current
        let days = (1...7).map { cal.date(byAdding: .day, value: $0, to: cal.startOfDay(for: .now))! }
        let counts = days.map { store.dueCount(on: $0) }
        let peak = max(1, counts.max() ?? 1)
        let f = DateFormatter(); f.dateFormat = "EEE"; f.locale = Locale(identifier: "en_US")
        return VStack(alignment: .leading, spacing: 10) {
            TrackedLabel(text: "Due next 7 days", color: Ink.ink)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days.indices, id: \.self) { i in
                    VStack(spacing: 3) {
                        Text("\(counts[i])").font(Typo.ui(10, .bold))
                        ZStack { if i == 0 { Ink.akane } else { Screentone(density: 0.6, spacing: 4) } }
                            .frame(height: max(3, 60 * CGFloat(counts[i]) / CGFloat(peak)))
                            .overlay(Rectangle().strokeBorder(i == 0 ? Ink.akane : Ink.ink, lineWidth: 1.5))
                        Text(f.string(from: days[i])).font(Typo.ui(10, .bold)).foregroundStyle(Ink.soft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
        }
        .padding(18).inkBox()
    }
}
