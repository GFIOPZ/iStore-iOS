import SwiftUI
import UIKit
import AVFoundation

// MARK: - Tactile press style (from SiteAgent GlassPressStyle)

struct GlassTactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.045 : 0)
            .animation(
                .spring(response: 0.20, dampingFraction: 0.82),
                value: configuration.isPressed
            )
    }
}

// MARK: - Text primitives

/// Small monospaced caption — key text style for values & badges.
struct MonoText: View {
    let text: String
    var size: CGFloat = 11
    var weight: Font.Weight = .medium
    var color: Color? = nil
    var tracking: CGFloat = 0

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(T.mono(size, weight))
            .foregroundColor(color ?? T.ink2)
            .tracking(tracking)
    }
}

/// Uppercase section header label in ink3.
struct CaptionText: View {
    let text: String
    var color: Color? = nil

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Text(LocalizedStringKey(text))
            .textCase(.uppercase)
            .font(T.sans(11, .bold))
            .foregroundColor(color ?? T.ink3)
            .tracking(0.4)
    }
}

// MARK: - Buttons

/// Primary action button with colorless glass hero surface.
struct GlassPrimaryButton: View {
    let label: String
    var systemImage: String? = nil
    var action: () -> Void = {}
    var disabled: Bool = false

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(LocalizedStringKey(label))
                    .font(T.sans(15, .semibold))
            }
            .foregroundColor(T.isDark ? .white : T.ink)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .glassSurface(.button)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    T.rule2,
                    lineWidth: AppStroke.hairline
                )
            }
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(GlassTactileButtonStyle())
        .disabled(disabled)
    }
}

/// Secondary action button — glass surface + subtle hairline rule.
struct GlassSecondaryButton: View {
    let label: String
    var systemImage: String? = nil
    var destructive: Bool = false
    var action: () -> Void = {}

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(
                            destructive
                                ? T.bad
                                : (T.isDark ? .white : T.ink)
                        )
                        .frame(width: 40, height: 40)
                        .fClearGlass(
                            in: RoundedRectangle(
                                cornerRadius: 11,
                                style: .continuous
                            )
                        )
                }

                Text(LocalizedStringKey(label))
                    .font(T.sans(17, .bold))
                    .foregroundColor(
                        destructive
                            ? T.bad
                            : (T.isDark ? .white : T.ink)
                    )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 66)
            .frame(maxWidth: .infinity)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            .glassSurface(.button)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    T.rule,
                    lineWidth: AppStroke.hairline
                )
            }
        }
        .buttonStyle(GlassTactileButtonStyle())
    }
}

// MARK: - Section & rows (grouped glass card chrome)

struct GlassSection<Content: View>: View {
    let title: String

    @ViewBuilder
    var content: () -> Content

    @Environment(\.forgeTheme) private var T

    init(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                CaptionText(text: title)

                Rectangle()
                    .fill(T.rule)
                    .frame(height: 1)
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .glassSurface(
                .card,
                cornerRadius: 18
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    T.rule,
                    lineWidth: AppStroke.hairline
                )
            }
        }
        .padding(.horizontal, T.pad)
        .padding(.top, 24)
    }
}

/// 1px rule divider used between rows inside a section card.
struct GlassRowDivider: View {
    @Environment(\.forgeTheme) private var T

    var body: some View {
        Rectangle()
            .fill(T.rule)
            .frame(height: 1)
    }
}

/// Row inside a GlassSection.
struct GlassRow<Trailing: View>: View {
    let label: String

    @ViewBuilder
    var trailing: () -> Trailing

    @Environment(\.forgeTheme) private var T

    var body: some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(label))
                .font(T.sans(15, .medium))
                .foregroundColor(T.ink)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// File-picker row.
struct GlassFileRow: View {
    let icon: String
    let label: String
    let file: URL?
    let action: () -> Void

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(T.accent2)
                    .frame(width: 40, height: 40)
                    .fClearGlass(
                        in: RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                    )

                Text(LocalizedStringKey(label))
                    .font(T.sans(15, .medium))
                    .foregroundColor(T.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(
                    LocalizedStringKey(
                        file?.lastPathComponent ?? "Choose…"
                    )
                )
                .font(
                    file == nil
                        ? T.sans(13)
                        : T.mono(12)
                )
                .foregroundColor(
                    file == nil
                        ? T.ink3
                        : T.ink2
                )
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(
                    maxWidth: 150,
                    alignment: .trailing
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassTactileButtonStyle())
    }
}

/// Text-input row.
struct GlassInputRow: View {
    let icon: String
    let label: String
    let placeholder: String

    @Binding
    var text: String

    var isSecure: Bool = false

    @Environment(\.forgeTheme) private var T

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(T.accent2)
                .frame(width: 22)

            Text(LocalizedStringKey(label))
                .font(T.sans(15, .medium))
                .foregroundColor(T.ink)

            Spacer(minLength: 8)

            Group {
                if isSecure {
                    SecureField(
                        LocalizedStringKey(placeholder),
                        text: $text
                    )
                } else {
                    TextField(
                        LocalizedStringKey(placeholder),
                        text: $text
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }
            }
            .textFieldStyle(.plain)
            .font(T.mono(13))
            .foregroundColor(T.ink)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 170)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// Toggle row.
struct GlassToggleRow: View {
    let label: String

    @Binding
    var isOn: Bool

    @Environment(\.forgeTheme) private var T

    var body: some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(label))
                .font(T.sans(15, .medium))
                .foregroundColor(T.ink)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Spacer(minLength: 8)

            GlassToggle(isOn: $isOn)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// Custom 32×18 glass toggle, spring-animated.
struct GlassToggle: View {
    @Binding
    var isOn: Bool

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Button {
            withAnimation(
                .spring(
                    response: 0.25,
                    dampingFraction: 0.85
                )
            ) {
                isOn.toggle()
            }
        } label: {
            ZStack(
                alignment: isOn
                    ? .trailing
                    : .leading
            ) {
                Capsule()
                    .fill(
                        isOn
                            ? T.controlTint
                            : T.ink4.opacity(0.4)
                    )
                    .frame(
                        width: 32,
                        height: 18
                    )

                Circle()
                    .fill(.white)
                    .frame(
                        width: 14,
                        height: 14
                    )
                    .shadow(
                        color: .black.opacity(0.18),
                        radius: 2,
                        y: 1
                    )
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            isOn ? "on" : "off"
        )
    }
}

// MARK: - Small primitives

/// Status pill — mono 9 semibold uppercase, colorless glass capsule.
struct GlassStatusPill: View {
    let text: String
    let color: Color

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Text(LocalizedStringKey(text))
            .textCase(.uppercase)
            .font(T.mono(9, .semibold))
            .tracking(0)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(
                        color.opacity(
                            T.isDark ? 0.16 : 0.12
                        )
                    )
            }
            .overlay {
                Capsule()
                    .stroke(
                        color.opacity(
                            T.isDark ? 0.40 : 0.28
                        ),
                        lineWidth: AppStroke.hairline
                    )
            }
    }
}

/// Bordered mono tag (e.g. a bundle id or version chip).
struct GlassTag: View {
    let text: String
    var size: CGFloat = 10

    @Environment(\.forgeTheme) private var T

    var body: some View {
        Text(text)
            .font(T.mono(size))
            .foregroundColor(T.ink2)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .glassSurface(.badge)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        T.rule,
                        lineWidth: AppStroke.hairline
                    )
            }
    }
}

// MARK: - Glass GET control

@MainActor
private final class InstallSoundPlayer {
    static let shared = InstallSoundPlayer()

    private var player: AVAudioPlayer?

    func play() {
        guard let url = Bundle.main.url(
            forResource: "InstallConfirm",
            withExtension: "wav"
        ) else {
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()

            try session.setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )

            try session.setActive(
                true,
                options: []
            )

            player = try AVAudioPlayer(
                contentsOf: url
            )

            player?.volume = 0.72
            player?.prepareToPlay()
            player?.play()

        } catch {
            // Sound is decorative; never interrupt or fail the install action.
        }
    }
}

enum ForgeInteractionFeedback {

    @MainActor
    static func playPressSound() {
        InstallSoundPlayer.shared.play()
    }

    @MainActor
    static func playLightHaptic() {
        let generator =
            UIImpactFeedbackGenerator(
                style: .light
            )

        generator.prepare()

        generator.impactOccurred(
            intensity: 0.42
        )
    }
}

struct InstallLoadingAnimation: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var isAnimating = false

    let color: Color

    init(
        color: Color = Color(
            red: 0.10,
            green: 0.42,
            blue: 0.94
        )
    ) {
        self.color = color
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(
                0..<3,
                id: \.self
            ) { index in

                Circle()
                    .fill(color)
                    .frame(
                        width: 7,
                        height: 7
                    )
                    .scaleEffect(
                        reduceMotion
                            ? 1
                            : (isAnimating
                                ? 1.12
                                : 0.72)
                    )
                    .offset(
                        y: reduceMotion
                            ? 0
                            : (isAnimating
                                ? -2
                                : 2)
                    )
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(
                                duration: 0.48
                            )
                            .repeatForever(
                                autoreverses: true
                            )
                            .delay(
                                Double(index) * 0.14
                            ),
                        value: isAnimating
                    )
            }
        }
        .frame(
            width: 76,
            height: 34
        )
        .onAppear {
            isAnimating = !reduceMotion
        }
        .onDisappear {
            isAnimating = false
        }
        .accessibilityLabel("Loading")
    }
}

struct GlassGetButton: View {
    let isLoading: Bool
    let isInstalled: Bool
    let disabled: Bool

    var emphasizesText = false

    let action: () -> Void

    @Environment(\.forgeTheme)
    private var T

    @AppStorage("app.language")
    private var languageCode =
        AppLanguage.english.rawValue

    @State
    private var hapticPulse = 0

    var body: some View {
        Button {

            guard !disabled else {
                return
            }

            hapticPulse &+= 1

            ForgeInteractionFeedback
                .playLightHaptic()

            if !isInstalled {
                playDownloadStartSound()
            }

            action()

        } label: {

            HStack(spacing: 6) {

                if isLoading {

                    InstallLoadingAnimation(
                        color: .white
                    )

                } else {

                    Text(
                        languageCode ==
                            AppLanguage.arabic.rawValue
                            ? (
                                isInstalled
                                    ? "فتح"
                                    : "تثبيت"
                            )
                            : (
                                isInstalled
                                    ? "OPEN"
                                    : "GET"
                            )
                    )
                    .font(
                        T.sans(
                            languageCode ==
                                AppLanguage.arabic.rawValue
                                ? 13.5
                                : 12.5,
                            .heavy
                        )
                    )
                    .tracking(
                        languageCode ==
                            AppLanguage.arabic.rawValue
                            ? 0.15
                            : 0.25
                    )
                }
            }

            // Zed Store: white text over a purple action button.
            .foregroundColor(
                disabled
                    ? Color.white.opacity(0.55)
                    : .white
            )

            .frame(
                width: 82,
                height: 36
            )

            // Purple gradient surface.
            .background {

                Capsule()
                    .fill(
                        LinearGradient(
                            colors:
                                disabled
                                    ? [
                                        T.ink4.opacity(0.35),
                                        T.ink4.opacity(0.20)
                                    ]
                                    : isLoading
                                        ? [
                                            T.accentDeep,
                                            T.accent
                                        ]
                                        : [
                                            T.accentDeep,
                                            T.accent,
                                            T.accentHi
                                        ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Fine white highlight around the button.
            .overlay {

                Capsule()
                    .stroke(
                        Color.white.opacity(
                            disabled
                                ? 0.05
                                : 0.22
                        ),
                        lineWidth: 0.8
                    )
            }

            // Soft purple glow.
            .shadow(
                color: T.accent.opacity(
                    disabled
                        ? 0
                        : 0.24
                ),
                radius: 9,
                x: 0,
                y: 4
            )

            .contentShape(Capsule())
        }

        .buttonStyle(
            GlassTactileButtonStyle()
        )

        .disabled(disabled)

        .opacity(
            disabled
                ? 0.52
                : 1
        )
    }

    /// A single quiet glass-like confirmation sound when the loading dots begin.
    /// It is not played for the Open state or repeated while a download is active.
    private func playDownloadStartSound() {
        ForgeInteractionFeedback.playPressSound()
    }
}

// MARK: - Navigation back control

/// Direction-aware back control used by sheets and detail screens.
/// The entire 48pt control area is tappable, not only the chevron glyph.
struct GlassBackButton: View {
    let action: () -> Void

    var symbolName = "chevron.backward"
    var mirrorsInRTL = true

    @Environment(\.forgeTheme)
    private var T

    var body: some View {
        Button(action: action) {

            Image(systemName: symbolName)
                .flipsForRightToLeftLayoutDirection(
                    mirrorsInRTL
                )
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundColor(
                    T.isDark
                        ? .white
                        : .black
                )
                .frame(
                    width: 64,
                    height: 48
                )
                .fNavigationGlass(
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .frame(
            width: 64,
            height: 48
        )
        .contentShape(Capsule())
        .buttonStyle(
            GlassTactileButtonStyle()
        )
        .accessibilityLabel("Back")
    }
}

/// Uses the exact same Liquid Glass back control as the import application
/// sheet, while keeping it pinned to the physical right in every language.
struct DirectionalGlassBackButton: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            GlassBackButton(
                action: action,
                symbolName: "chevron.right",
                mirrorsInRTL: false
            )
            .zIndex(100)
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(maxWidth: .infinity)
    }
}

extension View {

    /// Places the shared back control above the navigation content instead of
    /// inside a toolbar, preventing iOS from adding its own white glass capsule.
    func floatingGlassBackButton(
        action: @escaping () -> Void
    ) -> some View {

        overlay {

            ZStack(alignment: .topTrailing) {

                Color.clear

                GlassBackButton(
                    action: action,
                    symbolName: "chevron.right",
                    mirrorsInRTL: false
                )
                .padding(.top, 12)
                .padding(.trailing, 12)
                .zIndex(1_000)
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
        }
    }
}
