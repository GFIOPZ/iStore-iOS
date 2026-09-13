import SwiftUI

struct NOVAVerificationView: View {
    @State private var rotation: Double = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 28) {

                ZStack {

                    Circle()
                        .fill(
                            Color(hex: "8B5CF6")
                                .opacity(0.10)
                        )
                        .frame(
                            width: 180,
                            height: 180
                        )
                        .blur(radius: 8)
                        .scaleEffect(
                            pulse ? 1.08 : 0.94
                        )

                    Circle()
                        .stroke(
                            Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                        .frame(
                            width: 145,
                            height: 145
                        )

                    Circle()
                        .trim(
                            from: 0.05,
                            to: 0.72
                        )
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: "A855F7"),
                                    Color(hex: "7C3AED"),
                                    Color.clear
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round
                            )
                        )
                        .frame(
                            width: 145,
                            height: 145
                        )
                        .rotationEffect(
                            .degrees(rotation)
                        )

                    Image(systemName: "shield.checkered")
                        .font(
                            .system(
                                size: 46,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "C084FC"),
                                    Color(hex: "8B5CF6")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(
                            color: Color(hex: "8B5CF6")
                                .opacity(0.35),
                            radius: 18
                        )
                }

                VStack(spacing: 9) {
                    Text("NOVA VIP")
                        .font(
                            .system(
                                size: 28,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .tracking(1.2)
                        .foregroundStyle(.white)

                    Text("جاري التحقق من الترخيص")
                        .font(
                            .system(
                                size: 17,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.82)
                        )

                    Text("يتم تأمين جلسة الدخول وتجهيز المتجر")
                        .font(
                            .system(
                                size: 13,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.38)
                        )
                }

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(
                                Color(hex: "A855F7")
                                    .opacity(0.75)
                            )
                            .frame(
                                width: 6,
                                height: 6
                            )
                            .scaleEffect(
                                pulse
                                ? 1
                                : 0.55
                            )
                            .animation(
                                .easeInOut(
                                    duration: 0.7
                                )
                                .repeatForever()
                                .delay(
                                    Double(index) * 0.16
                                ),
                                value: pulse
                            )
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(
                .linear(duration: 2.1)
                    .repeatForever(
                        autoreverses: false
                    )
            ) {
                rotation = 360
            }

            withAnimation(
                .easeInOut(duration: 1)
                    .repeatForever(
                        autoreverses: true
                    )
            ) {
                pulse = true
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "06040A"),
                    Color(hex: "0D0717"),
                    Color(hex: "11091F"),
                    Color(hex: "06040A")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    Color(hex: "7C3AED")
                        .opacity(0.14)
                )
                .frame(width: 300)
                .blur(radius: 90)
                .offset(x: -130, y: -260)

            Circle()
                .fill(
                    Color(hex: "A855F7")
                        .opacity(0.09)
                )
                .frame(width: 260)
                .blur(radius: 90)
                .offset(x: 150, y: 270)
        }
    }
}
