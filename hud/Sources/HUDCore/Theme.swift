import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// The single source of truth for the instrument-cluster palette and type ramp.
// Never inline a hex or a font size at a call site; reach for a token here.
public enum Theme {

    // MARK: Colors
    //
    // Every semantic token is a *dynamic* color: it resolves to the light hex
    // in Aqua and the dark hex in Dark Aqua, so the HUD follows the system
    // appearance with no toggle. The palette is the Pitch dashboard's
    // (~/pitch/hud/assets/theme.css): green-tinted neutrals, pitch green as the
    // working accent, forest green for notes and pressure, red for spent and
    // blocked. No orange or amber anywhere.
    // Pitch is light-only, so the dark values are its hues carried onto a
    // near-black green card.
    // The menu-bar glance is unaffected — it renders monochrome as a template.
    public static let notch    = dynamic(light: 0xF6F7F4, dark: 0x000000)
    public static let panel    = dynamic(light: 0xFFFFFF, dark: 0x0F1311)
    public static let panel2   = dynamic(light: 0xF0F2EF, dark: 0x161B18)
    public static let hairline = dynamic(light: 0xE4E7E2, dark: 0x28302B)
    public static let text     = dynamic(light: 0x17201A, dark: 0xF0F3F1)
    public static let muted    = dynamic(light: 0x6C7570, dark: 0x8A948E)
    // `faint` is the recessive tier — captions, the meter rows a pod is not
    // headlining — but it still carries readings, so it is held at 3:1 against
    // the card it sits on rather than allowed to fade to decoration.
    public static let faint    = dynamic(light: 0x858D87, dark: 0x66706A)
    public static let green    = dynamic(light: 0x2E9E5B, dark: 0x4CC27A)
    public static let red      = dynamic(light: 0xC0303C, dark: 0xFF6B74)
    // Forest green: "look at this" — a quota under 25%, a setup problem count,
    // a stale reading, the rotator switched off. Pitch's deepest primary, so it
    // reads apart from the healthy `green`.
    public static let forest   = dynamic(light: 0x175E36, dark: 0x7FC29D)

    // The working accent: what a control says it does ("fix in a new session",
    // the copy button). Pitch's link green, a step deeper than `green` so it
    // reads as text on the accent surface.
    public static let accent        = dynamic(light: 0x1F7A45, dark: 0x5CC085)
    // A problem row's own surface: pitch green washed into the card so a row
    // you can act on reads as a block rather than as coloured text.
    // The row's count is drawn in `forest` on it, so the row invites the fix
    // without shouting.
    public static let accentSurface = dynamic(light: 0xE3F2E9, dark: 0x13241A)
    public static let accentBorder  = dynamic(light: 0xCDE8D9, dark: 0x1F3A2A)
    // A copyable command sits in a chip that reads as terminal: recessed on the
    // dark card, raised (white, hairlined) on the light one.
    public static let chip        = dynamic(light: 0xFFFFFF, dark: 0x0A0D0B)
    public static let chipBorder  = dynamic(light: 0xE4E7E2, dark: 0x0A0D0B)

    // Brand marks. Claude takes forest rather than its coral, so the card has
    // no orange in it; the Codex mark draws in `text` on the card (see
    // providerColor).
    public static let claudeMark  = forest
    public static let codexGreen  = dynamic(light: 0x109965, dark: 0x19C37D)

    /// A color that resolves per system appearance: `light` in Aqua, `dark` in
    /// Dark Aqua. On platforms without AppKit it collapses to the dark value.
    public static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
        #else
        return Color(hex: dark)
        #endif
    }

    // MARK: Severity
    /// Ring / meter color driven by percent remaining.
    /// Fully spent (0) reads red, pressured (<25) forest, otherwise green.
    /// A null reading has no severity and renders as the track color.
    public static func severity(pctLeft: Int?) -> Color {
        guard let pct = pctLeft else { return hairline }
        if pct <= 0 { return red }
        if pct < 25 { return forest }
        return green
    }

    /// The brand mark tint for a subscription provider on the card. Claude is
    /// forest; Codex draws in `text` (ink on the light card, near-white on the
    /// dark one) since a fixed white mark would vanish on a white surface.
    public static func providerColor(_ provider: String) -> Color {
        provider == "codex" ? text : claudeMark
    }

    /// The dot beside a pod's "2 agents" line. One colour, not a palette: the
    /// card counts agents per subscription rather than listing them, so there is
    /// nothing left to tell apart by hue. Deliberately clear of the severity
    /// green/forest/red the quota meters own, so it never reads as a warning.
    public static let agentDot = dynamic(light: 0x1F87A8, dark: 0x4EC9E0)

    // MARK: Type
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    public static func label(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension Color {
    /// Construct an opaque color from a packed 0xRRGGBB integer.
    public init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

#if canImport(AppKit)
extension NSColor {
    /// Construct an opaque color from a packed 0xRRGGBB integer, in sRGB so it
    /// matches the SwiftUI `Color(hex:)` above.
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif
