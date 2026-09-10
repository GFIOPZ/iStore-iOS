import SwiftUI

// MARK: - Color Extensions

extension Color {

    init(hex: String) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet(charactersIn: "# ")
        )

        var value: UInt64 = 0

        guard !hex.isEmpty,
              Scanner(string: hex).scanHexInt64(&value) else {
            self = .clear
            return
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    init(hex: UInt32, alpha: Double = 1) {
        self = Color(
            hex: String(format: "%06X", hex)
        )
        .opacity(alpha)
    }

    init(light: String, dark: String) {
        self = Color(
            UIColor { trait in
                UIColor(
                    Color(
                        hex: trait.userInterfaceStyle == .dark
                        ? dark
                        : light
                    )
                )
            }
        )
    }
}

// MARK: - Zed Store Theme

struct ForgeTheme {

    // Background
    let bg: Color
    let surface: Color
    let surface2: Color
    let surface3: Color

    // Text
    let ink: Color
    let ink2: Color
    let ink3: Color
    let ink4: Color

    // Borders
    let rule: Color
    let rule2: Color

    // Brand
    let accent: Color
    let accentSoft: Color
    let accentSofter: Color

    // Semantic
    let good: Color
    let warn: Color
    let bad: Color

    // Layout
    let pad: CGFloat
    let gap: CGFloat

    let isDark: Bool

    // Gradient colors
    let accentHi: Color
    let accentDeep: Color
    let accentStrong: Color
}

// MARK: - Zed Store Palettes

extension ForgeTheme {

    /// Zed Store Light Theme
    static let light = ForgeTheme(

        // MARK: Background

        bg: Color(hex: "F7F5FC"),

        surface: Color.white,

        surface2: Color(hex: "FBF9FF"),

        surface3: Color(hex: "F1ECFA"),

        // MARK: Text

        ink: Color(hex: "17131F"),

        ink2: Color(hex: "625A6D"),

        ink3: Color(hex: "8E8798"),

        ink4: Color(hex: "B9B2C1"),

        // MARK: Borders

        rule: Color(hex: "E5DFF0"),

        rule2: Color(hex: "D5CCE5"),

        // MARK: Zed Purple

        accent: Color(hex: "7C3AED"),

        accentSoft: Color(hex: "7C3AED")
            .opacity(0.12),

        accentSofter: Color(hex: "7C3AED")
            .opacity(0.06),

        // MARK: Semantic

        good: Color(hex: "22A06B"),

        warn: Color(hex: "D58A16"),

        bad: Color(hex: "DC3545"),

        // MARK: Layout

        pad: 18,

        gap: 14,

        isDark: false,

        // MARK: Purple Gradient

        accentHi: Color(hex: "A855F7"),

        accentDeep: Color(hex: "5B21B6"),

        accentStrong: Color(hex: "7C3AED")
    )


    /// Zed Store Dark Theme
    static let dark = ForgeTheme(

        // MARK: Background

        bg: Color(hex: "100C16"),

        surface: Color(hex: "1A1422"),

        surface2: Color(hex: "211A2B"),

        surface3: Color(hex: "281F34"),

        // MARK: Text

        ink: Color(hex: "F7F2FF"),

        ink2: Color(hex: "C7BED1"),

        ink3: Color(hex: "9B91A7"),

        ink4: Color(hex: "696071"),

        // MARK: Borders

        rule: Color.white.opacity(0.10),

        rule2: Color.white.opacity(0.18),

        // MARK: Zed Purple

        accent: Color(hex: "A855F7"),

        accentSoft: Color(hex: "A855F7")
            .opacity(0.18),

        accentSofter: Color(hex: "A855F7")
            .opacity(0.09),

        // MARK: Semantic

        good: Color(hex: "4ADE80"),

        warn: Color(hex: "FBBF24"),

        bad: Color(hex: "FB7185"),

        // MARK: Layout

        pad: 18,

        gap: 14,

        isDark: true,

        // MARK: Purple Gradient

        accentHi: Color(hex: "C084FC"),

        accentDeep: Color(hex: "6D28D9"),

        accentStrong: Color(hex: "A855F7")
    )


    // MARK: - Control Colors

    var controlTint: Color {
        accent
    }

    var accentStrongSoft: Color {
        accentStrong.opacity(
            isDark ? 0.20 : 0.12
        )
    }

    var accent2: Color {
        accent
    }
}

// MARK: - Typography

extension ForgeTheme {

    /// Large Zed Store headings
    func display(
        _ size: CGFloat,
        _ weight: Font.Weight = .semibold
    ) -> Font {
        .system(
            size: size,
            weight: weight,
            design: .rounded
        )
    }

    /// Normal application text
    func sans(
        _ size: CGFloat,
        _ weight: Font.Weight = .medium
    ) -> Font {
        .system(
            size: size,
            weight: weight,
            design: .default
        )
    }

    /// Technical / small text
    func mono(
        _ size: CGFloat,
        _ weight: Font.Weight = .medium
    ) -> Font {
        .system(
            size: size,
            weight: weight,
            design: .monospaced
        )
    }
}

// MARK: - Environment

private struct ForgeThemeKey: EnvironmentKey {

    static let defaultValue: ForgeTheme = .light
}

extension EnvironmentValues {

    var forgeTheme: ForgeTheme {

        get {
            self[ForgeThemeKey.self]
        }

        set {
            self[ForgeThemeKey.self] = newValue
        }
    }
}

extension View {

    func forgeTheme(
        _ theme: ForgeTheme
    ) -> some View {
        self.environment(
            \.forgeTheme,
            theme
        )
    }

    func forgeScaledType() -> some View {
        self.dynamicTypeSize(
            ...DynamicTypeSize.accessibility2
        )
    }
}
