import SwiftUI

// MARK: - Color Palette (Pink/Purple Neon — Kiraa)

extension Color {
    /// Deep dark background with purple undertone
    nonisolated static let appBackground = Color(hex: "0A0610")
    /// Card/surface background
    nonisolated static let surface       = Color(hex: "110D1A")
    /// Secondary surface (banners, elevated elements)
    nonisolated static let surface2      = Color(hex: "16112A")
    /// Borders and dividers
    nonisolated static let border        = Color(hex: "2A1F45")

    /// Python/CPU baseline accent — warm amber-pink
    nonisolated static let pythonAmber   = Color(hex: "FF6B9D")
    /// Swift/Metal GPU challenger accent — electric neon purple
    nonisolated static let swiftCyan     = Color(hex: "BF5AF2")
    /// Danger/anomaly highlight — hot neon pink
    nonisolated static let danger        = Color(hex: "FF2D78")

    /// Kiraa brand accent — bright neon magenta
    nonisolated static let kiraaAccent   = Color(hex: "E040FB")
    /// Secondary accent — electric blue-violet
    nonisolated static let neonViolet    = Color(hex: "7C4DFF")

    /// Very muted text
    nonisolated static let mutedText     = Color(hex: "3D2858")
    /// Dim text (labels, captions)
    nonisolated static let dimText       = Color(hex: "6A5080")
    /// Body text
    nonisolated static let bodyText      = Color(hex: "D0C0E8")
    /// Bright text (headings, values)
    nonisolated static let whiteText     = Color(hex: "F0E8F8")
}

extension Color {
    /// Create a Color from a 6-digit hex string (e.g. "00E5FF" or "#00E5FF").
    ///
    /// Parses the hex into a UInt64, then extracts R/G/B channels via bitwise
    /// shifts: bits 16–23 = red, bits 8–15 = green, bits 0–7 = blue.
    nonisolated init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - Font Helpers

extension Font {
    nonisolated static let monoCaption  = Font.system(.caption2, design: .monospaced)
    nonisolated static let monoSmall    = Font.system(.footnote, design: .monospaced)
    nonisolated static let monoBody     = Font.system(.body, design: .monospaced).weight(.bold)
    nonisolated static let displayLarge = Font.system(size: 48, weight: .black, design: .rounded)
    nonisolated static let displayMed   = Font.system(size: 28, weight: .bold, design: .rounded)
    nonisolated static let sectionLabel = Font.system(.caption2, design: .monospaced).weight(.medium)
}
