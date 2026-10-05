import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Palette — 墨 sumi · 和紙 washi · 茜 akane
// Every token resolves per appearance; dark mode swaps ink and paper.

enum Ink {
    static let paper   = dynamic(0xF3EFE6, dark: 0x121110)   // 和紙 app ground
    static let card    = dynamic(0xFBF9F4, dark: 0x1D1B19)   // 胡粉 card surface
    static let ink     = dynamic(0x1B1A18, dark: 0xECE6DA)   // 墨 text / ink
    static let soft    = dynamic(0x5F5A52, dark: 0xA8A196)   // 鼠 secondary text
    static let line    = dynamic(0xD8D1C3, dark: 0x3A3631)   // 灰 hairlines
    static let chip    = dynamic(0xE9E3D7, dark: 0x2A2724)
    static let akane   = dynamic(0xB7282E, dark: 0xD9443F)   // 茜 the one accent
    static let enji    = dynamic(0x8E1C21, dark: 0xB23530)   // 臙脂 pressed
    static let onAkane = Color(hex: 0xF3EFE6)
    static let onInk   = dynamic(0xF3EFE6, dark: 0x121110)

    private static func dynamic(_ light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { t in
            UIColor(hex: t.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        Color(nsColor: NSColor(name: nil) { a in
            NSColor(hex: a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
typealias PlatformColor = UIColor
#else
typealias PlatformColor = NSColor
#endif

extension PlatformColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    #if canImport(UIKit)
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
    #else
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
    #endif
}

// MARK: - Type
// Hiragino Mincho ships with iOS — brush-like display face for every Japanese
// word on a card. UI text uses the system face (Hiragino Sans / Thai fallback).

enum Typo {
    static func mincho(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "HiraMinProN-W6" : "HiraMinProN-W3", size: size)
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    /// Tracked caps label — newspaper style.
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .heavy) }
}

struct TrackedLabel: View {
    let text: String
    var color: Color = Ink.soft
    var size: CGFloat = 11
    var body: some View {
        Text(text.uppercased())
            .font(Typo.label(size))
            .tracking(size * 0.2)
            .foregroundStyle(color)
    }
}

// MARK: - Appearance setting

enum Appearance: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var scheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
    var title: String {
        switch self { case .system: "System"; case .light: "Light"; case .dark: "Dark" }
    }
}

// MARK: - Haptics

enum Haptic {
    #if os(iOS)
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thud() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    #else
    // Mac: trackpad haptics only where the system already gives them.
    static func tap() {}
    static func thud() {}
    static func success() { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default) }
    static func warning() { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default) }
    #endif
}
