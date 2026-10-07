import SwiftUI

/// Elegant Floating Live Download Bar mirroring iOS Dynamic Island & Lock Screen style
/// Displays real-time progress, file name, download percentage, and status message.
public struct DownloadNotificationOverlay: View {
    @ObservedObject private var manager = BackgroundDownloadManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(manager.activeDownloads.values), id: \.id) { download in
                downloadCard(for: download)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                    ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56) // Clean clearance below Dynamic Island and notch
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: manager.activeDownloads.keys.count)
    }

    @ViewBuilder
    private func downloadCard(for download: ActiveDownload) -> some View {
        HStack(spacing: 13) {
            // App Icon
            Group {
                if let iconURL = download.iconURL {
                    AsyncImage(url: iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            fallbackIcon
                        }
                    }
                } else {
                    fallbackIcon
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)

            // Info & Progress Bar
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(download.appName.hasSuffix(".ipa") ? download.appName : "\(download.appName).ipa")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    if case .completed = download.status {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: "34D399"))
                            Text("100%")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "34D399"))
                        }
                    } else {
                        Text("\(Int(download.progress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }

                // Custom Animated Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.22))
                            .frame(height: 6)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "93C5FD"),
                                        Color(hex: "60A5FA"),
                                        Color.white
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * CGFloat(download.progress)), height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: download.progress)
                    }
                }
                .frame(height: 6)

                // Subtitle / Status
                HStack {
                    switch download.status {
                    case .downloading(_, let bytes, let total):
                        if total > 0 {
                            Text("\(formatBytes(bytes)) من \(formatBytes(total))")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        } else {
                            Text("جارٍ التحميل في الخلفية...")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    case .completed:
                        Text("اكتمل التحميل! جارٍ تجهيز رسالة التثبيت...")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color(hex: "A7F3D0"))
                    case .failed(let err):
                        Text("فشل: \(err)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color(hex: "FCA5A5"))
                            .lineLimit(1)
                    case .queued:
                        Text("في الانتظار...")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                }
            }

            // Cancel / Dismiss Button
            if case .completed = download.status {
                EmptyView()
            } else {
                Button {
                    BackgroundDownloadManager.shared.cancelDownload(appId: download.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Blur + Gradient
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1E40AF").opacity(0.95),
                                Color(hex: "1E3A8A").opacity(0.97)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 16, y: 8)
        .shadow(color: Color(hex: "1E40AF").opacity(0.3), radius: 20, y: 10)
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.18))
            Image(systemName: "arrow.down.app.fill")
                .foregroundStyle(.white)
                .font(.system(size: 18))
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
