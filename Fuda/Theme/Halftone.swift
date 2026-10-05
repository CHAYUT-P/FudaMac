import SwiftUI

// MARK: - Halftone field (manga screentone)
// A rotated dot lattice whose radius follows a fade — real print halftone,
// not an opacity wash.

enum ToneFade {
    case uniform, left, right, up, down
    case radial(UnitPoint, inner: CGFloat, outer: CGFloat)

    func strength(_ p: CGPoint, _ s: CGSize) -> CGFloat {
        guard s.width > 0, s.height > 0 else { return 0 }
        switch self {
        case .uniform: return 1
        case .left:  return 1 - p.x / s.width
        case .right: return p.x / s.width
        case .up:    return 1 - p.y / s.height
        case .down:  return p.y / s.height
        case let .radial(c, inner, outer):
            let cx = c.x * s.width, cy = c.y * s.height
            let r = hypot(s.width, s.height) / 2
            let d = hypot(p.x - cx, p.y - cy) / r
            if d <= inner { return 1 }
            if d >= outer { return 0 }
            return 1 - (d - inner) / (outer - inner)
        }
    }
}

struct HalftoneField: View {
    var fade: ToneFade = .uniform
    var spacing: CGFloat = 7
    var maxRadius: CGFloat = 2.6
    var angle: Double = 22
    var color: Color = Ink.ink

    var body: some View {
        Canvas { ctx, size in
            let a = angle * .pi / 180
            let ca = cos(a), sa = sin(a)
            let cx = size.width / 2, cy = size.height / 2
            let half = hypot(size.width, size.height) / 2 + spacing
            var path = Path()
            var v = -half
            while v < half {
                var u = -half
                while u < half {
                    let x = cx + u * ca - v * sa
                    let y = cy + u * sa + v * ca
                    if x > -spacing, y > -spacing, x < size.width + spacing, y < size.height + spacing {
                        let s = max(0, min(1, fade.strength(CGPoint(x: x, y: y), size)))
                        let r = maxRadius * sqrt(s)
                        if r > 0.35 { path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)) }
                    }
                    u += spacing
                }
                v += spacing
            }
            ctx.fill(path, with: .color(color))
        }
        .allowsHitTesting(false)
    }
}

/// Flat screentone at a given density (0…1) — used for mastery fills.
struct Screentone: View {
    var density: CGFloat
    var spacing: CGFloat = 4
    var color: Color = Ink.ink
    var body: some View {
        HalftoneField(fade: .uniform, spacing: spacing, maxRadius: spacing * 0.5 * min(1, density * 1.25), angle: 0, color: color)
    }
}

// MARK: - 日の丸 tone — red halftone sun

struct HalftoneSun: View {
    var size: CGFloat = 260
    var body: some View {
        ZStack {
            HalftoneField(fade: .radial(.center, inner: 0.35, outer: 0.98), spacing: 8, maxRadius: 3.4, angle: 15, color: Ink.akane)
                .frame(width: size, height: size)
                .clipShape(Circle())
            Circle().fill(Ink.akane).frame(width: size * 0.46, height: size * 0.46)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 集中線 focus lines

struct FocusLines: View {
    var count = 72
    var color: Color = Ink.ink
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let rOuter = hypot(size.width, size.height)
            let rInner = min(size.width, size.height) * 0.28
            for i in 0..<count {
                let base: CGFloat = CGFloat(i) / CGFloat(count) * 2 * .pi
                let a: CGFloat = base + (i.isMultiple(of: 3) ? 0.02 : 0)
                let jitter: CGFloat = CGFloat((i * 37) % 11) / 11 * 0.12
                let w: CGFloat = 0.012 + CGFloat((i * 13) % 5) * 0.002
                let r0: CGFloat = rInner * (1 + jitter)
                let p1 = CGPoint(x: c.x + cos(a - w) * rOuter, y: c.y + sin(a - w) * rOuter)
                let p2 = CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0)
                let p3 = CGPoint(x: c.x + cos(a + w) * rOuter, y: c.y + sin(a + w) * rOuter)
                var p = Path()
                p.move(to: p1)
                p.addLine(to: p2)
                p.addLine(to: p3)
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 印 seals

struct HankoSeal: View {
    let text: String
    var size: CGFloat = 120
    var angle: Double = -6
    var body: some View {
        Text(text)
            .font(Typo.mincho(size * 0.64))
            .foregroundStyle(Ink.onAkane)
            .frame(width: size, height: size)
            .background(Ink.akane)
            .overlay(Rectangle().strokeBorder(Ink.onAkane, lineWidth: max(1.5, size * 0.018)).padding(size * 0.05))
            .rotationEffect(.degrees(angle))
            .accessibilityLabel(text)
    }
}

struct OutlineStamp: View {
    let text: String
    var size: CGFloat = 14
    var angle: Double = -3
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(Ink.akane)
            .padding(.horizontal, size * 0.7)
            .padding(.vertical, size * 0.4)
            .overlay(Rectangle().strokeBorder(Ink.akane, lineWidth: 2))
            .overlay(Rectangle().strokeBorder(Ink.akane, lineWidth: 1).padding(3))
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Dot meter

struct DotMeter: View {
    var value: Double
    var count = 10
    var size: CGFloat = 6
    var body: some View {
        HStack(spacing: size * 0.55) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i < Int((value * Double(count)).rounded()) ? Ink.ink : Ink.line)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(Int(value * 100)) percent")
    }
}

// MARK: - Crop marks

struct CropMarks: ViewModifier {
    var offset: CGFloat = 8
    var length: CGFloat = 16
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { g in
                cropPath(g.size).stroke(Ink.ink, lineWidth: 1.5)
            }
            .allowsHitTesting(false)
        )
    }

    private func cropPath(_ size: CGSize) -> Path {
        let w = size.width, h = size.height, o = offset, l = length
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(-o, -o, 1, 1), (w + o, -o, -1, 1), (-o, h + o, 1, -1), (w + o, h + o, -1, -1)]
        var p = Path()
        for (x, y, dx, dy) in corners {
            p.move(to: CGPoint(x: x + dx * l, y: y))
            p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + dy * l))
        }
        return p
    }
}

extension View {
    func cropMarks() -> some View { modifier(CropMarks()) }
}

// MARK: - Section header — kanji numeral + tracked caps + rule

struct SectionRule: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            TrackedLabel(text: title)
            Rectangle().fill(Ink.ink).frame(height: 2)
            if let trailing { Text(trailing).font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft) }
        }
    }
}

// MARK: - Buttons

struct InkButtonStyle: ButtonStyle {
    enum Kind { case akane, ink, outline, akaneOutline }
    var kind: Kind = .akane
    var height: CGFloat = 58

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 16, weight: .heavy))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(fg)
            .background(bg(pressed))
            .overlay(Rectangle().strokeBorder(border, lineWidth: 2))
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
    private var fg: Color {
        switch kind { case .akane: Ink.onAkane; case .ink: Ink.onInk; case .outline: Ink.ink; case .akaneOutline: Ink.akane }
    }
    private var border: Color {
        switch kind { case .akane, .akaneOutline: Ink.akane; case .ink, .outline: Ink.ink }
    }
    private func bg(_ pressed: Bool) -> Color {
        switch kind {
        case .akane: pressed ? Ink.enji : Ink.akane
        case .ink: pressed ? Ink.soft : Ink.ink
        case .outline, .akaneOutline: pressed ? Ink.chip : Ink.card
        }
    }
}

/// Two-option level switch (N5 / N4) — black fill on the chosen one.
struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var height: CGFloat = 32
    var fill = false
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { opt in
                Button {
                    Haptic.tap()
                    withAnimation(.snappy(duration: 0.2)) { selection = opt.0 }
                } label: {
                    Text(opt.1)
                        .font(.system(size: 13, weight: .heavy))
                        .frame(minWidth: 44, maxWidth: fill ? .infinity : nil, minHeight: height)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                        .foregroundStyle(selection == opt.0 ? Ink.onInk : Ink.ink)
                        .background(selection == opt.0 ? Ink.ink : Color.clear)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == opt.0 ? .isSelected : [])
            }
        }
        .background(Ink.paper)
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
    }
}

/// Small grey tag — "VERB · 動詞".
struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .tracking(1.4)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Ink.chip)
            .foregroundStyle(Ink.ink)
    }
}
