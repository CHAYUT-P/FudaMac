import SwiftUI

// MARK: - Small pieces

struct Kbd: View {
    let key: String
    var light = false            // on akane / ink buttons
    init(_ key: String, light: Bool = false) { self.key = key; self.light = light }
    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(light ? Ink.onAkane.opacity(0.6) : Ink.line, lineWidth: 1))
            .foregroundStyle(light ? Ink.onAkane.opacity(0.9) : Ink.soft)
    }
}

/// Standard pane header: kicker, mincho title, subtitle, trailing controls.
struct PaneHeader<Trailing: View>: View {
    let kicker: String
    let title: String
    var subtitle: String = ""
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                TrackedLabel(text: kicker)
                Text(title).font(Typo.mincho(30)).foregroundStyle(Ink.ink)
                if !subtitle.isEmpty { Text(subtitle).font(Typo.ui(13)).foregroundStyle(Ink.soft) }
            }
            Spacer()
            trailing()
        }
    }
}

extension PaneHeader where Trailing == EmptyView {
    init(kicker: String, title: String, subtitle: String = "") {
        self.init(kicker: kicker, title: title, subtitle: subtitle) { EmptyView() }
    }
}

extension View {
    /// Card surface with an ink border.
    func inkBox(_ fill: Color = Ink.card, border: Color = Ink.ink, width: CGFloat = 2) -> some View {
        background(fill).overlay(Rectangle().strokeBorder(border, lineWidth: width))
    }
}

/// A list column used left of a detail pane (lessons, scenes, stories, chapters).
struct ListColumn<Content: View>: View {
    var width: CGFloat = 280
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(.bottom, 20)
        }
        .frame(width: width)
        .background(Ink.paper)
        .overlay(alignment: .trailing) { Rectangle().fill(Ink.ink).frame(width: 2) }
    }
}

struct ListGroupLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(Ink.soft)
            .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A selectable row in a list column.
struct ListRow: View {
    let title: String
    var subtitle: String = ""
    var trailing: String = ""
    var trailingAccent = false
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    MixedText(title, size: 15, weight: .bold, color: selected ? Ink.onInk : Ink.ink)
                    if !subtitle.isEmpty { Text(subtitle).font(Typo.ui(11)).opacity(0.75).lineLimit(1) }
                }
                Spacer(minLength: 4)
                if !trailing.isEmpty {
                    Text(trailing).font(trailing.count <= 2 ? Typo.mincho(13) : Typo.ui(11, .heavy))
                        .foregroundStyle(trailingAccent ? (selected ? Color(hex: 0xE5605B) : Ink.akane) : (selected ? Ink.line : Ink.soft))
                }
            }
            .padding(.horizontal, 10).frame(minHeight: 36)
            .foregroundStyle(selected ? Ink.onInk : Ink.ink)
            .background(selected ? Ink.ink : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Mastery strip (ink density per memory stage).
struct MacMasteryStrip: View {
    let counts: [Mastery: Int]
    var height: CGFloat = 16
    var body: some View {
        let total = max(1, counts.values.reduce(0, +))
        GeometryReader { g in
            HStack(spacing: 0) {
                ForEach(Mastery.allCases.reversed(), id: \.self) { m in
                    let w = g.size.width * CGFloat(counts[m] ?? 0) / CGFloat(total)
                    if w > 0 {
                        ZStack { Ink.card; if m == .mature { Ink.ink } else if m != .new { Screentone(density: m.density) } }
                            .frame(width: w)
                    }
                }
            }
        }
        .frame(height: height)
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
    }
}

/// Word / kanji / grammar row with mastery swatch, used in lists and search.
struct MacCardRow: View {
    @Environment(ProgressStore.self) private var store
    let card: Card
    var body: some View {
        let m = store.mastery(card.id)
        HStack(spacing: 12) {
            ZStack { Ink.card; if m == .mature { Ink.ink } else if m != .new { Screentone(density: m.density, spacing: 3) } }
                .frame(width: 12, height: 12)
                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.2))
            Group {
                if card.kind == .vocab || card.kind == .kanji {
                    JPText(ja: card.prompt, kana: card.kind == .vocab ? card.reading : "", size: 20, bold: true, romajiText: card.romaji)
                } else {
                    Text(card.prompt).font(Typo.mincho(card.kind == .grammar ? 16 : 20)).lineLimit(1)
                }
            }
            .frame(width: 170, alignment: .leading)
            Text(card.meaning).font(Typo.ui(14)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if !card.meaningEN.isEmpty {
                Text(card.meaningEN).font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(1).frame(width: 160, alignment: .leading)
            }
            Button { Speech.shared.say(card.speech) } label: { Image(systemName: "speaker.wave.2").foregroundStyle(Ink.soft) }
                .buttonStyle(.plain).accessibilityLabel("Play audio")
            Button { store.toggleStar(card.id) } label: {
                Text(store.isStarred(card.id) ? "★" : "☆").foregroundStyle(Ink.akane)
            }
            .buttonStyle(.plain).accessibilityLabel(store.isStarred(card.id) ? "Unstar" : "Star")
        }
        .foregroundStyle(Ink.ink)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
    }
}

/// Toggle chip for ふ / A / TH·EN.
struct ToggleSquare: View {
    let text: String
    @Binding var on: Bool
    var label: String
    var body: some View {
        Button { on.toggle() } label: {
            Text(text).font(text.count == 1 ? Typo.mincho(16) : Typo.ui(12, .heavy))
                .frame(minWidth: 34, minHeight: 34)
                .padding(.horizontal, text.count == 1 ? 0 : 8)
                .foregroundStyle(on ? Ink.onInk : Ink.ink)
                .background(on ? Ink.ink : .clear)
                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "On" : "Off")
    }
}

struct ReadingToggles: View {
    @Environment(ProgressStore.self) private var store
    var body: some View {
        @Bindable var store = store
        HStack(spacing: 6) {
            ToggleSquare(text: "ふ", on: $store.settings.showFurigana, label: "Furigana")
            ToggleSquare(text: "A", on: $store.settings.showRomaji, label: "Romaji")
            ToggleSquare(text: "EN", on: $store.settings.showEnglish, label: "English")
        }
    }
}

/// Wrapping row layout for chips.
struct Flow: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height); widest = max(widest, x)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

/// Akane primary / ink / outline button label helpers on top of InkButtonStyle.
struct StampBadge: View {
    let text: String
    var size: CGFloat = 46
    var body: some View {
        Text(text).font(Typo.mincho(size * 0.5)).foregroundStyle(Ink.onAkane)
            .frame(width: size, height: size).background(Ink.akane)
            .overlay(Rectangle().strokeBorder(Ink.onAkane, lineWidth: 1.2).padding(3))
            .rotationEffect(.degrees(-6))
    }
}

/// Japanese sentence with optional kana line, romaji and translations.
struct SentenceBlock: View {
    @Environment(ProgressStore.self) private var store
    let ja: String
    let kana: String
    var romaji: String = ""
    let th: String
    let en: String
    var size: CGFloat = 19
    var highlight: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            JPText(ja: ja, kana: kana, size: size, highlight: highlight, romajiText: romaji)
            Text(th).font(Typo.ui(13)).foregroundStyle(Ink.ink)
            if store.settings.showEnglish, !en.isEmpty { Text(en).font(Typo.ui(12)).foregroundStyle(Ink.soft) }
        }
        .textSelection(.enabled)
    }
}

struct SpeakIcon: View {
    let text: String
    var size: CGFloat = 32
    var body: some View {
        Button { Speech.shared.say(text) } label: {
            Image(systemName: "play.fill").font(.system(size: size * 0.32))
                .foregroundStyle(Ink.ink)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play audio")
    }
}

/// Section rule with a kanji numeral.
struct NumberedRule: View {
    let numeral: String
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Text(numeral).font(Typo.mincho(22)).foregroundStyle(Ink.akane)
            TrackedLabel(text: title, color: Ink.ink)
            Rectangle().fill(Ink.ink).frame(height: 2)
        }
    }
}
