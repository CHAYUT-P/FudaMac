import SwiftUI

// 話 Conversations: the real-life scenes shared with the iPhone app
// (Resources/conversations.json). Read with notes, or role-play your part.

struct MacTalkView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router

    var body: some View {
        let scenes = Talk.scenes
        let cur = scenes.first { $0.id == router.talkID } ?? scenes.first
        HStack(spacing: 0) {
            ListColumn(width: 290) {
                VStack(alignment: .leading, spacing: 4) {
                    TrackedLabel(text: "話 · Conversations")
                    Text("Must-know talk").font(Typo.mincho(26))
                    Text("\(scenes.count) real-life scenes · \(scenes.filter { course.talks.contains($0.id) }.count) done").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                }
                .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 4)
                ForEach(TalkPlace.allCases) { place in
                    let items = scenes.filter { $0.place == place }
                    if !items.isEmpty {
                        ListGroupLabel(text: "\(place.ja) · \(place.en.uppercased())")
                        ForEach(items) { s in
                            ListRow(title: s.title, subtitle: "\(s.en) · \(s.level.title)", trailing: course.talks.contains(s.id) ? "済" : "", trailingAccent: true, selected: s.id == cur?.id) {
                                router.talkID = s.id
                            }
                        }
                    }
                }
            }
            if let s = cur { ScenePlayer(scene: s).id(s.id) }
        }
    }
}

struct ScenePlayer: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    let scene: TalkScene
    @State private var mode = 0                 // 0 read, 1 role-play
    @State private var focus: TalkLine?
    @State private var turn = 0
    @State private var picked: Int?
    @State private var playing: String?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                if mode == 0 { transcript } else { rolePlay }
            }
            .frame(maxWidth: .infinity)
            sidePanel
        }
        .onDisappear { Speech.shared.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    MixedText(scene.title, size: 30, weight: .bold).fixedSize()
                    Text("\(scene.en) · \(scene.level.title) · \(scene.spoken.count) lines · you say \(scene.yourLines)").font(Typo.ui(13)).foregroundStyle(Ink.soft).lineLimit(1)
                }
                Spacer()
                ReadingToggles()
            }
            MixedText(store.settings.showEnglish ? scene.aboutEN : scene.aboutTH, size: 13, color: Ink.soft)
            HStack(spacing: 0) {
                tab("読む", "Read", 0)
                tab("役", "Role-play", 1)
                Spacer()
                if mode == 0 {
                    Button { playAll() } label: { HStack { Image(systemName: "play.fill"); Text("Play all") } }
                        .buttonStyle(InkButtonStyle(kind: .ink, height: 34)).frame(width: 120)
                    Button("Stop") { Speech.shared.stop(); playing = nil }
                        .buttonStyle(InkButtonStyle(kind: .outline, height: 34)).frame(width: 70).padding(.leading, 6)
                }
            }
        }
        .padding(.horizontal, 30).padding(.top, 22)
        .background(Ink.card)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }
    }

    private func tab(_ ja: String, _ en: String, _ i: Int) -> some View {
        Button { mode = i; turn = 0; picked = nil } label: {
            HStack(spacing: 6) { Text(ja).font(Typo.mincho(16)); Text(en).font(Typo.ui(13, .heavy)) }
                .padding(.horizontal, 18).frame(height: 44)
                .foregroundStyle(mode == i ? Ink.ink : Ink.soft)
                .background(mode == i ? Ink.paper : .clear)
                .overlay(alignment: .bottom) { Rectangle().fill(mode == i ? Ink.akane : .clear).frame(height: 4) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Read

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(scene.lines.enumerated()), id: \.offset) { _, line in
                    if line.isSection {
                        HStack(spacing: 10) {
                            Text(line.ja).font(Typo.mincho(15)).foregroundStyle(Ink.akane)
                            Text(store.settings.showEnglish ? line.en : line.th).font(Typo.ui(12, .heavy)).foregroundStyle(Ink.soft)
                            Rectangle().fill(Ink.line).frame(height: 1)
                        }
                        .padding(.top, 10)
                    } else {
                        bubble(line)
                    }
                }
                Button("Mark conversation done ✓") { course.markTalk(scene.id) }
                    .buttonStyle(InkButtonStyle(kind: course.talks.contains(scene.id) ? .ink : .outline, height: 40)).frame(width: 260)
                    .padding(.top, 10)
            }
            .padding(30)
        }
    }

    private func bubble(_ line: TalkLine) -> some View {
        let mine = line.you
        let sel = focus == line
        return HStack(alignment: .top, spacing: 12) {
            if mine { Spacer(minLength: 80) } else { who(line) }
            Button { focus = line; Speech.shared.say(line.kana.isEmpty ? line.ja : line.kana, voice: mine ? .main : .partner) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    SentenceBlock(ja: line.ja, kana: line.kana, romaji: line.romaji, th: line.th, en: line.en, size: 19)
                    if line.key { Text("KEY PHRASE").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(Ink.akane).padding(.top, 2) }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: 520, alignment: .leading)
                .inkBox(Ink.card, border: sel || playing == line.ja ? Ink.akane : Ink.ink)
                .background(Rectangle().fill(sel ? Ink.akane : .clear).offset(x: 4, y: 4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if mine { who(line) } else { Spacer(minLength: 80) }
        }
    }

    private func who(_ line: TalkLine) -> some View {
        let name = line.you ? "あなた" : (line.speaker.isEmpty ? "—" : line.speaker)
        return Text(name).font(.system(size: 12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
            .frame(width: 60, height: 26)
            .foregroundStyle(line.you ? Ink.onAkane : Ink.ink)
            .background(line.you ? Ink.akane : Ink.chip)
            .help(line.you ? "You" : scene.roleName(line.speaker, english: true))
    }

    private func playAll() {
        let lines = scene.spoken
        func play(_ i: Int) {
            guard i < lines.count else { playing = nil; return }
            playing = lines[i].ja
            Speech.shared.say(lines[i].kana.isEmpty ? lines[i].ja : lines[i].kana, voice: lines[i].you ? .main : .partner) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if playing == lines[i].ja { play(i + 1) } }
            }
        }
        play(0)
    }

    // MARK: Role-play

    private var rolePlay: some View {
        let turns = RolePlay.turns(for: scene)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("You are あなた. Read what they say, choose your reply, and say it out loud. Keys 1–3 choose, ↩ continues.")
                    .font(Typo.ui(13, .bold)).foregroundStyle(Ink.akane)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().strokeBorder(Ink.akane, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                ForEach(turns.prefix(turn + 1)) { t in
                    ForEach(Array(t.prompts.enumerated()), id: \.offset) { _, p in bubble(p) }
                    if let answer = t.answer {
                        if t.id < turn { bubble(answer) } else { choices(t, answer: answer, last: t.id == turns.count - 1) }
                    } else if t.id == turn {
                        finished
                    }
                }
                if turn >= turns.count { finished }
            }
            .padding(30)
        }
    }

    private func choices(_ t: TalkTurn, answer: TalkLine, last: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            TrackedLabel(text: "Your turn · あなたの番", color: Ink.akane, size: 10)
            ForEach(t.options.indices, id: \.self) { i in
                let st: (Color, Color, Color) = picked == nil ? (Ink.card, Ink.ink, Ink.ink) : i == t.correct ? (Ink.ink, Ink.onInk, Ink.ink) : i == picked ? (Ink.akane, Ink.onAkane, Ink.akane) : (Ink.card, Ink.soft, Ink.line)
                Button {
                    guard picked == nil else { return }
                    picked = i
                    if i == t.correct { Haptic.success(); Speech.shared.say(answer.kana.isEmpty ? answer.ja : answer.kana) } else { Haptic.warning() }
                } label: {
                    HStack { Kbd("\(i + 1)"); Text(t.options[i]).font(Typo.mincho(18)) }
                        .padding(.horizontal, 14).frame(minHeight: 46).frame(maxWidth: 560, alignment: .leading)
                        .foregroundStyle(st.1).background(st.0).overlay(Rectangle().strokeBorder(st.2, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [])
            }
            if picked != nil {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(answer.th)\(store.settings.showEnglish ? " · " + answer.en : "")").font(Typo.ui(13))
                    if !answer.noteEN.isEmpty { MixedText(store.settings.showEnglish ? answer.noteEN : answer.noteTH, size: 12, color: Ink.soft) }
                    Button { turn += 1; picked = nil } label: { HStack { Text("Continue"); Kbd("↩", light: true) } }
                        .buttonStyle(InkButtonStyle(kind: .akane, height: 40)).frame(width: 160)
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var finished: some View {
        HStack(spacing: 14) {
            StampBadge(text: "済")
            Text("Scene complete").font(Typo.ui(16, .heavy))
            Spacer()
            Button("Again") { turn = 0; picked = nil }.buttonStyle(InkButtonStyle(kind: .outline, height: 40)).frame(width: 100)
        }
        .padding(.top, 10)
        .onAppear { course.markTalk(scene.id) }
    }

    // MARK: Side panel

    private var sidePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let f = focus {
                    VStack(alignment: .leading, spacing: 6) {
                        TrackedLabel(text: f.you ? "Your line" : scene.roleName(f.speaker, english: store.settings.showEnglish), color: Ink.akane, size: 10)
                        SentenceBlock(ja: f.ja, kana: f.kana, romaji: f.romaji, th: f.th, en: f.en, size: 20)
                        if !f.noteEN.isEmpty || !f.noteTH.isEmpty {
                            MixedText(store.settings.showEnglish ? f.noteEN : f.noteTH, size: 13).padding(.top, 4)
                        }
                        if !f.alts.isEmpty {
                            TrackedLabel(text: "You could also say", size: 10).padding(.top, 6)
                            ForEach(f.alts, id: \.ja) { a in
                                VStack(alignment: .leading, spacing: 1) { JPText(ja: a.ja, kana: a.kana, size: 15, bold: true, romajiText: a.romaji); Text(a.th).font(Typo.ui(12)).foregroundStyle(Ink.soft) }
                            }
                        }
                        let words = DB.shared.vocab.filter { $0.kanji.count >= 2 && !$0.kanji.contains("〜") && f.ja.contains($0.kanji) }.prefix(5)
                        if !words.isEmpty {
                            TrackedLabel(text: "Words", size: 10).padding(.top, 6)
                            ForEach(Array(words)) { w in
                                HStack { Text(w.kanji).font(Typo.mincho(15)); Text(w.kana).font(Typo.ui(11)).foregroundStyle(Ink.soft); Spacer(); Text(w.th).font(Typo.ui(12)).lineLimit(1) }
                            }
                        }
                    }
                    .padding(14).inkBox()
                } else {
                    Text("Click any line to see notes, alternatives and words.").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                }
                VStack(alignment: .leading, spacing: 0) {
                    TrackedLabel(text: "決まり文句 · Key phrases", color: Ink.ink, size: 10).padding(.bottom, 6)
                    ForEach(scene.keyPhrases, id: \.ja) { k in
                        Button { focus = k; Speech.shared.say(k.kana.isEmpty ? k.ja : k.kana, voice: .partner) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                JPText(ja: k.ja, kana: k.kana, size: 15, bold: true, romajiText: k.romaji)
                                MixedText(store.settings.showEnglish ? (k.noteEN.isEmpty ? k.en : k.noteEN) : (k.noteTH.isEmpty ? k.th : k.noteTH), size: 12, color: Ink.soft)
                            }
                            .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(22)
        }
        .frame(width: 320)
        .background(Ink.chip.opacity(0.6))
        .overlay(alignment: .leading) { Rectangle().fill(Ink.ink).frame(width: 2) }
    }
}
