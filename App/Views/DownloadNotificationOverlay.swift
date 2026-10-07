import SwiftUI

/// Elegant Floating Live Download Bar mirroring iOS Dynamic Island & Lock Screen Live Activity style
/// Matches the requested design:
/// - Left: Unified NOVA Store Logo / App Icon (44x44 with rounded corners and subtle border)
/// - Center: App/Game filename (e.g. 8_Ball_Pool10.ipa) and percentage (e.g. 9%)
/// - Right: Circular progress loader with stop/cancel button in the center
public struct DownloadNotificationOverlay: View {
    @ObservedObject private var manager = BackgroundDownloadManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(manager.activeDownloads.values), id: \.id) { download in
                downloadCapsule(for: download)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92)),
                        removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.90))
                    ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.activeDownloads.keys.count)
    }

    @ViewBuilder
    private func downloadCapsule(for download: ActiveDownload) -> some View {
        HStack(spacing: 14) {
            appIconView(for: download)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(formattedFileName(for: download.appName))
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if case .completed = download.status {
                    Text("100%")
                        .font(.system(size: 13.5, weight: .medium, design: .default))
                        .foregroundStyle(Color(hex: "34D399"))
                } else if case .failed(let err) = download.status {
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(Color(hex: "F87171"))
                        .lineLimit(1)
                } else {
                    Text("\(Int(max(0, min(100, download.progress * 100))))%")
                        .font(.system(size: 13.5, weight: .regular, design: .default))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }

            Spacer(minLength: 8)

            Button {
                HapticFeedback.light()
                manager.cancelDownload(appId: download.id)
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 3.2)
                        .frame(width: 36, height: 36)

                    if case .completed = download.status {
                        Circle()
                            .fill(Color(hex: "10B981"))
                            .frame(width: 36, height: 36)

                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .trim(from: 0.0, to: CGFloat(max(0.04, min(1.0, download.progress))))
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                            )
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: download.progress)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 11, height: 11)
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(height: 68)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "0D1B2A").opacity(0.92),
                                Color(hex: "1B263B").opacity(0.88),
                                Color(hex: "0B132B").opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.40), radius: 14, x: 0, y: 7)
    }

    @ViewBuilder
    private func appIconView(for download: ActiveDownload) -> some View {
        if let iconURL = download.iconURL {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    storeFallbackLogo
                }
            }
        } else {
            storeFallbackLogo
        }
    }

    private var storeFallbackLogo: some View {
        Group {
            if let uiImage = UIImage(named: "NOVAStoreLogo") ?? UIImage(named: "AppIcon") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "4C1D95"), Color(hex: "1E1B4B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func formattedFileName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasSuffix(".ipa") {
            return trimmed
        }
        return "\(trimmed).ipa"
    }
}

private enum HapticFeedback {
    @MainActor static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
