import SwiftUI

// MARK: - Zed Store Grid

struct GridTexture: View {
    var spacing: CGFloat = 42
    var color: Color = Color(hex: "7C3AED").opacity(0.055)

    var body: some View {
        Canvas { ctx, size in
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            ctx.stroke(
                path,
                with: .color(color),
                lineWidth: 0.55
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Zed Store Backdrop

struct ForgeBackdrop: View {

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {

            // Main background
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(hex: "100C16"),
                        Color(hex: "160F20"),
                        Color(hex: "100C16")
                    ]
                    : [
                        Color(hex: "FFFFFF"),
                        Color(hex: "F8F4FF"),
                        Color(hex: "F4EEFF")
                    ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Purple ambient glow - top right
            RadialGradient(
                colors: [
                    Color(hex: "A855F7").opacity(
                        colorScheme == .dark ? 0.20 : 0.11
                    ),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 360
            )

            // Purple ambient glow - bottom left
            RadialGradient(
                colors: [
                    Color(hex: "7C3AED").opacity(
                        colorScheme == .dark ? 0.14 : 0.055
                    ),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 420
            )

            // Technical grid
            GridTexture(
                spacing: 42,
                color: Color(hex: "7C3AED").opacity(
                    colorScheme == .dark ? 0.075 : 0.055
                )
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
