import SwiftUI

// MARK: - Lesson script model
// A lesson is a list of beats. Each beat lays out tokens on a stage. Tokens
// keep their id across beats, so pressing Next "magic-moves" them: a verb
// ending slides out, its replacement flies in from the rule row, a timeline
// bar grows. A subtitle types out underneath to explain the beat.

struct LessonTok: Identifiable, Hashable {
    enum Kind: Hashable { case plain, key, ink, ghost, op, strike, label, note }
    enum Size: Hashable { case huge, big, mid, small }
    let id: String
    var text: String
    var kind: Kind = .plain
    var size: Size = .big
    var ruby: String? = nil
    var caption: String? = nil
}

struct LessonTimeline: Hashable {
    var bar: ClosedRange<CGFloat>? = nil       // 0…1 along the axis
    var solid = false                          // solid = resulting state, tone = in progress
    var event: CGFloat? = nil                  // instant-change dot
    var eventLabel = ""
    var ticks: [CGFloat] = []                  // habit marks
    var caption = ""
}

struct LessonRow: Identifiable, Hashable {
    let id: String
    var toks: [LessonTok] = []
    var timeline: LessonTimeline? = nil
    var spacing: CGFloat = 10
}

struct LessonChapter: Hashable { let title: String; let start: Int }

struct LessonBeat: Hashable {
    var kicker: String
    var rows: [LessonRow]
    var en: String
    var th: String
    var say: String? = nil
}

// Builders keep the scripts readable.
func tk(_ id: String, _ text: String, _ kind: LessonTok.Kind = .plain, _ size: LessonTok.Size = .big, ruby: String? = nil, caption: String? = nil) -> LessonTok {
    LessonTok(id: id, text: text, kind: kind, size: size, ruby: ruby, caption: caption)
}
func rw(_ id: String, spacing: CGFloat = 10, _ toks: [LessonTok]) -> LessonRow { LessonRow(id: id, toks: toks, spacing: spacing) }
func tl(_ t: LessonTimeline, id: String = "timeline") -> LessonRow { LessonRow(id: id, timeline: t) }

// MARK: - Player

struct LessonPlayer: View {
    @Environment(ProgressStore.self) private var store
    let title: String
    let beats: [LessonBeat]
    var start = 0
    var chapters: [LessonChapter] = []
    var video = false                 // video mode: plays by itself, chapter bar, pause and speed
    var onFinish: () -> Void = {}

    @Namespace private var ns
    @State private var index = 0
    @State private var typing = Typing()         // own observable, so typing only redraws the subtitle
    @State private var autoplay = false
    @State private var replayTick = 0
    @AppStorage("lessonSubtitleLang") private var subLang = "th"   // one subtitle language, no second translation
    @AppStorage("videoSpeed") private var speed = 1.0

    private var beat: LessonBeat { beats[min(index, max(0, beats.count - 1))] }

    var body: some View {
        if beats.isEmpty {
            Text("No lesson here yet").font(Typo.ui(15, .heavy)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            player
        }
    }

    private var player: some View {
        VStack(spacing: 0) {
            if !chapters.isEmpty { chapterBar }
            stage
            SubtitleBar(text: subtitle, say: beat.say, typing: typing)
            controls
        }
        .background(Ink.paper)
        .task(id: "\(index)-\(replayTick)") { await play() }
        .task(id: "\(index)-\(replayTick)-\(autoplay)") { await autoAdvance() }
        .onAppear {
            if start > 0 { index = min(start, beats.count - 1) }
            if video && start == 0 { autoplay = true }
        }
        .onDisappear { Speech.shared.stop() }
    }

    // MARK: Chapters

    private var chapter: Int { chapters.lastIndex { $0.start <= index } ?? 0 }

    private var chapterBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(chapters.indices, id: \.self) { i in
                        let on = i == chapter
                        let end = i + 1 < chapters.count ? chapters[i + 1].start : beats.count
                        let done = index >= end
                        Button { go(chapters[i].start) } label: {
                            HStack(spacing: 8) {
                                Text(done ? "✓" : "\(i + 1)").font(Typo.ui(11, .heavy))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(on ? Ink.onAkane : done ? Ink.onInk : Ink.soft)
                                    .background(on ? Ink.akane : done ? Ink.ink : Ink.chip)
                                Text(chapters[i].title).font(Typo.ui(13, on ? .heavy : .semibold))
                                    .foregroundStyle(on ? Ink.ink : Ink.soft)
                                    .lineLimit(1)
                                    .frame(maxWidth: on ? 360 : (chapters.count > 5 ? 120 : 220), alignment: .leading)
                            }
                            .padding(.horizontal, 12).frame(height: 40)
                            .background(on ? Ink.card : .clear)
                            .overlay(alignment: .bottom) { Rectangle().fill(on ? Ink.akane : .clear).frame(height: 3) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(chapters[i].title)
                        .id(i)
                    }
                }
            }
            .onChange(of: chapter) { _, c in withAnimation { proxy.scrollTo(c, anchor: .center) } }
            .onAppear { proxy.scrollTo(chapter, anchor: .center) }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
        .padding(.bottom, 10)
    }

    // MARK: Stage

    private var stage: some View {
        ZStack(alignment: .topLeading) {
            Ink.card
            HalftoneField(fade: .radial(UnitPoint(x: 1, y: 0), inner: 0.05, outer: 0.45), spacing: 7, maxRadius: 2.2).opacity(0.35)
            HalftoneField(fade: .radial(UnitPoint(x: 0, y: 1), inner: 0.0, outer: 0.35), spacing: 7, maxRadius: 2.2, color: Ink.akane).opacity(0.25)
            HStack {
                Text(beat.kicker.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(2).foregroundStyle(Ink.akane)
                    .contentTransition(.opacity)
                Spacer()
                Text("\(title) · \(index + 1) / \(beats.count)").font(Typo.ui(11, .heavy)).foregroundStyle(Ink.soft)
            }
            .padding(18)
            VStack(spacing: 26) {
                let crowded = beat.rows.contains { $0.timeline != nil } || beat.rows.count >= 3
                ForEach(beat.rows) { row in rowView(row, crowded: crowded) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40).padding(.top, 50).padding(.bottom, 24)
        }
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
        .clipped()
        .frame(minHeight: 180, maxHeight: .infinity)
    }

    /// Step a size down when the row is long or the stage is crowded, so a
    /// beat always fits without scrolling.
    private func fit(_ size: LessonTok.Size, chars: Int, crowded: Bool) -> LessonTok.Size {
        let order: [LessonTok.Size] = [.huge, .big, .mid, .small]
        var i = order.firstIndex(of: size) ?? 1
        if crowded { i += 1 }
        if size == .huge && chars > 6 { i += 1 }
        if chars > 14 { i += 1 }
        if chars > 26 { i += 1 }
        return order[min(i, order.count - 1)]
    }

    @ViewBuilder private func rowView(_ row: LessonRow, crowded: Bool) -> some View {
        if let t = row.timeline {
            TimelineStage(t: t)
                .frame(height: 150)
                .matchedGeometryEffect(id: row.id, in: ns)
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Flow(spacing: row.spacing) {
                let chars = row.toks.filter { $0.kind != .label && $0.kind != .note }.reduce(0) { $0 + $1.text.count }
                ForEach(Array(row.toks.enumerated()), id: \.element.id) { i, t in
                    TokView(tok: { var x = t; if x.kind != .note && x.kind != .label { x.size = fit(t.size, chars: chars, crowded: crowded) }; return x }())
                        .matchedGeometryEffect(id: t.id, in: ns)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.4, anchor: .bottom).combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.12 + Double(i) * 0.07)),
                            removal: .opacity.animation(.easeOut(duration: 0.18))))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Subtitles

    /// The subtitle in the chosen language, falling back to whichever the beat has.
    private var subtitle: String {
        if subLang == "en", !beat.en.isEmpty { return beat.en }
        return beat.th.isEmpty ? beat.en : beat.th
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button { go(index - 1) } label: { HStack { Kbd("←"); Text("Back") } }
                .buttonStyle(InkButtonStyle(kind: .outline, height: 44)).frame(width: 110)
                .keyboardShortcut(.leftArrow, modifiers: []).disabled(index == 0)
            Button { Speech.shared.stop(); replayTick += 1 } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(InkButtonStyle(kind: .outline, height: 44)).frame(width: 50).accessibilityLabel("Replay beat")
            HStack(spacing: 4) {
                ForEach(beats.indices, id: \.self) { i in
                    Button { go(i) } label: {
                        Rectangle().fill(i < index ? Ink.ink : i == index ? Ink.akane : Ink.line).frame(height: 6).contentShape(Rectangle().inset(by: -6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            if hasBothLanguages {
                Segmented(options: [("th", "ไทย"), ("en", "EN")], selection: $subLang, height: 30).help("Subtitle language")
            }
            if video {
                Segmented(options: [(0.75, "ช้า"), (1.0, "ปกติ"), (1.5, "เร็ว")], selection: $speed, height: 30).help("Reading speed")
                Button { toggleAutoplay() } label: {
                    Image(systemName: autoplay ? "pause.fill" : "play.fill").font(.system(size: 15, weight: .heavy))
                }
                .buttonStyle(InkButtonStyle(kind: .ink, height: 44)).frame(width: 50)
                .keyboardShortcut("k", modifiers: [])
                .help(autoplay ? "Pause (K)" : "Play (K)")
            } else {
                Toggle(isOn: $autoplay) { HStack(spacing: 4) { Image(systemName: "play.circle"); Text("Auto").font(Typo.ui(12, .heavy)) } }.toggleStyle(.button)
            }
            Button { next() } label: { HStack { Text(index == beats.count - 1 ? "Done ✓" : "Next"); Kbd("Space", light: true) } }
                .buttonStyle(InkButtonStyle(kind: .akane, height: 44)).frame(width: 140)
                .keyboardShortcut(.space, modifiers: [])
            Button("") { next() }.keyboardShortcut(.rightArrow, modifiers: []).opacity(0).frame(width: 1).accessibilityHidden(true)
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
    }

    private var hasBothLanguages: Bool { beats.contains { !$0.en.isEmpty && !$0.th.isEmpty } }

    private func toggleAutoplay() {
        autoplay.toggle()       // the autoAdvance task restarts and waits for this beat to finish
    }

    private func next() {
        if typing.typed < subtitle.count { typing.typed = subtitle.count; return }   // first press finishes the subtitle
        if index < beats.count - 1 { go(index + 1) } else { onFinish() }
    }

    private func go(_ i: Int) {
        guard beats.indices.contains(i) else { return }
        Speech.shared.stop()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) { index = i }
    }

    /// Type the subtitle and say the Japanese.
    private func play() async {
        typing.typed = 0
        let text = subtitle
        let say = beat.say
        try? await Task.sleep(for: .milliseconds(350))
        if let say, !Task.isCancelled { Speech.shared.say(say) }
        while typing.typed < text.count, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(24))
            typing.typed = min(text.count, typing.typed + 8)
        }
    }

    /// With autoplay on: wait until the beat is typed and spoken, give time to read, then move on.
    private func autoAdvance() async {
        guard autoplay else { return }
        let at = index
        try? await Task.sleep(for: .milliseconds(500))      // let play() reset the subtitle and start the voice
        while !Task.isCancelled, typing.typed < subtitle.count || Speech.shared.isSpeaking {
            try? await Task.sleep(for: .milliseconds(150))
        }
        let read = video ? Double(1500 + subtitle.count * 30) / max(0.5, speed) : Double(900 + subtitle.count * 12)
        try? await Task.sleep(for: .milliseconds(Int(read)))
        guard !Task.isCancelled, autoplay, index == at else { return }
        if index < beats.count - 1 { go(index + 1) } else { autoplay = false }
    }
}

@Observable final class Typing { var typed = 0 }

/// The typed-out subtitle. Lives in its own view so the stage doesn't redraw on every character.
private struct SubtitleBar: View {
    let text: String
    let say: String?
    let typing: Typing

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if typing.typed >= text.count {
                    // Fully typed: Japanese inside the subtitle gets furigana / romaji.
                    MixedText(text, size: 19, weight: .semibold)
                } else {
                    ZStack(alignment: .topLeading) {
                        Text(text).opacity(0)               // reserves the final height
                        Text(String(text.prefix(typing.typed)))
                    }
                    .font(Typo.ui(19, .semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            if let say {
                Button { Speech.shared.say(say) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 15)).foregroundStyle(Ink.onAkane)
                        .frame(width: 38, height: 38).background(Circle().fill(Ink.akane))
                }
                .buttonStyle(.plain).keyboardShortcut("p", modifiers: []).accessibilityLabel("Play Japanese")
            }
        }
        .padding(.leading, 20).padding(.trailing, 22).padding(.vertical, 16)
        .frame(minHeight: 104, alignment: .top)
        .overlay(alignment: .leading) { Rectangle().fill(Ink.akane).frame(width: 6) }
        .background(Ink.ink.opacity(0.04))
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
        .textSelection(.enabled)
    }
}

// MARK: - Token

struct TokView: View {
    @Environment(ProgressStore.self) private var store
    let tok: LessonTok

    private var fontSize: CGFloat {
        switch tok.size { case .huge: 84; case .big: 46; case .mid: 28; case .small: 17 }
    }

    /// Real Japanese only: no Latin letters (formula slots like "Vます"), at least one kana or kanji.
    private var isJapanese: Bool {
        guard [.plain, .key, .ink, .ghost, .strike].contains(tok.kind) else { return false }
        let scalars = tok.text.unicodeScalars
        if scalars.contains(where: { ("A"..."Z").contains($0) || ("a"..."z").contains($0) }) { return false }
        return scalars.contains { (0x3041...0x30FA).contains($0.value) || $0.properties.isIdeographic }
    }

    /// Reading for the whole token: the script's ruby, or the text itself when it's all kana.
    private var reading: String? {
        if let r = tok.ruby?.trimmingCharacters(in: .whitespaces), !r.isEmpty { return r }
        return tok.text.contains(where: Furigana.isKanji) ? nil : tok.text
    }

    var body: some View {
        let jp = isJapanese
        let showRuby = store.settings.showFurigana && jp
        VStack(spacing: 4) {
            styled(glyphs(showRuby: showRuby))
            if store.settings.showRomaji && jp, let reading {
                Text(["は": "wa", "へ": "e", "を": "o"][tok.text] ?? Furigana.romaji(tok.text, reading)).font(Typo.ui(max(10, fontSize * 0.24))).foregroundStyle(Ink.soft)
            }
            if let c = tok.caption {
                Text(c.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(1.4)
                    .foregroundStyle(tok.kind == .key ? Ink.akane : Ink.soft)
            }
        }
    }

    /// The token's characters with furigana over each kanji run (when on).
    @ViewBuilder private func glyphs(showRuby: Bool) -> some View {
        if showRuby {
            let segs = reading.map { Furigana.segments(tok.text, $0) } ?? tok.text.map { Furigana.Seg(base: String($0), ruby: nil) }
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                    VStack(spacing: 0) {
                        Text(seg.ruby ?? " ").font(Typo.ui(max(9, fontSize * 0.26), .semibold))
                            .opacity(seg.ruby == nil || !seg.base.contains(where: Furigana.isKanji) ? 0 : 0.8)
                            .lineLimit(1).fixedSize()
                        Text(seg.base).font(Typo.mincho(fontSize)).lineLimit(1).fixedSize()
                    }
                }
            }
        } else {
            Text(tok.text).font(Typo.mincho(fontSize)).lineLimit(1).fixedSize()
        }
    }

    @ViewBuilder private func styled<V: View>(_ v: V) -> some View {
        let pad = fontSize * 0.14
        switch tok.kind {
        case .plain:
            v.foregroundStyle(Ink.ink)
        case .key:
            v.foregroundStyle(Ink.onAkane).padding(.horizontal, pad).background(Ink.akane)
        case .ink:
            v.foregroundStyle(Ink.onInk).padding(.horizontal, pad).background(Ink.ink)
        case .ghost:
            v.foregroundStyle(Ink.soft).padding(.horizontal, pad)
                .overlay(Rectangle().strokeBorder(Ink.soft, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        case .op:
            Text(tok.text).font(.system(size: fontSize * 0.7, weight: .heavy)).foregroundStyle(Ink.akane)
        case .strike:
            v.foregroundStyle(Ink.soft.opacity(0.6))
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.akane).frame(height: max(3, fontSize * 0.07)).rotationEffect(.degrees(-8)).offset(y: -fontSize * 0.45) }
        case .label:
            Text(tok.text).font(Typo.ui(max(16, fontSize * 0.5), .heavy)).foregroundStyle(Ink.soft)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.5))
        case .note:
            MixedText(tok.text, size: fontSize * 0.55, weight: .semibold, center: true)
                .frame(maxWidth: 640)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Ink.paper).overlay(Rectangle().strokeBorder(Ink.akane, lineWidth: 2))
        }
    }
}

// MARK: - Timeline

struct TimelineStage: View {
    let t: LessonTimeline
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, y = h * 0.62
            let x0: CGFloat = 20, x1 = w - 30
            let px = { (f: CGFloat) in x0 + (x1 - x0) * f }
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Ink.ink).frame(width: x1 - x0, height: 2).position(x: (x0 + x1) / 2, y: y)
                Text("▶").font(.system(size: 13, weight: .heavy)).position(x: x1 + 8, y: y)
                Text("PAST").font(.system(size: 10, weight: .heavy)).tracking(1.4).foregroundStyle(Ink.soft).position(x: x0 + 24, y: y + 18)
                Text("FUTURE").font(.system(size: 10, weight: .heavy)).tracking(1.4).foregroundStyle(Ink.soft).position(x: x1 - 24, y: y + 18)
                if let b = t.bar {
                    let bw = max(4, px(b.upperBound) - px(b.lowerBound))
                    Group {
                        if t.solid { Rectangle().fill(Ink.ink) } else { Screentone(density: 0.55, spacing: 5).background(Ink.card).overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2)) }
                    }
                    .frame(width: bw, height: 34)
                    .position(x: px(b.lowerBound) + bw / 2, y: y)
                }
                ForEach(t.ticks, id: \.self) { f in
                    Screentone(density: 0.6, spacing: 4).frame(width: 14, height: 30)
                        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2)).position(x: px(f), y: y)
                }
                if let e = t.event {
                    Circle().fill(Ink.akane).frame(width: 24, height: 24).overlay(Circle().strokeBorder(Ink.card, lineWidth: 3)).position(x: px(e), y: y)
                    Text(t.eventLabel).font(Typo.mincho(15)).foregroundStyle(Ink.akane).position(x: px(e), y: y - 34)
                }
                Rectangle().fill(Ink.akane).frame(width: 3, height: h - 16).position(x: px(0.6), y: h / 2 + 6)
                Text("NOW 今").font(.system(size: 10, weight: .heavy)).tracking(1.4).foregroundStyle(Ink.onAkane)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(Ink.akane).position(x: px(0.6), y: 6)
                if !t.caption.isEmpty {
                    let cx = t.bar.map { px(($0.lowerBound + $0.upperBound) / 2) } ?? t.event.map(px) ?? px(0.6)
                    Text(t.caption).font(Typo.ui(13, .heavy)).padding(.horizontal, 6).background(Ink.card).fixedSize()
                        .position(x: min(max(cx, x0 + 120), x1 - 120), y: y + 44)
                }
            }
        }
        .frame(maxWidth: 820)
    }
}
