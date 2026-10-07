import SwiftUI

/// Elegant Floating Live Download Bar mirroring iOS Live Activity notifications
/// Shows progress percentage, file name, download bar, and cancel action.
public struct DownloadNotificationOverlay: View {
    @ObservedObject private var manager = BackgroundDownloadManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(manager.activeDownloads.values), id: \.id) { download in
                downloadCard(for: download)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: manager.activeDownloads.keys.count)
    }

    @ViewBuilder
    private func downloadCard(for download: ActiveDownload) -> some View {
        HStack(spacing: 12) {
            // Icon
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

            // Info & Progress Bar
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(download.appName.hasSuffix(".ipa") ? download.appName : "\(download.appName).ipa")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(Int(download.progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                }

                // Custom Animated Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color(hex: "93C5FD")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * CGFloat(download.progress)), height: 6)
                            .animation(.linear(duration: 0.2), value: download.progress)
                    }
                }
                .frame(height: 6)

                // Subtitle / Size status
                HStack {
                    switch download.status {
                    case .downloading(_, let bytes, let total):
                        if total > 0 {
                            Text("\(formatBytes(bytes)) / \(formatBytes(total))")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        } else {
                            Text("جاري التحميل في الخلفية...")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    case .completed:
                        Text("اكتمل التنزيل! جاري التثبيت...")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white)
                    case .failed(let err):
                        Text("فشل: \(err)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.9))
                    case .queued:
                        Text("في الانتظار...")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                }
            }

            // Cancel Button
            Button {
                BackgroundDownloadManager.shared.cancelDownload(appId: download.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            // Premium iOS Notification Gradient matching screenshot
            LinearGradient(
                colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: Color(hex: "1D4ED8").opacity(0.35), radius: 14, y: 6)
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.18))
            Image(systemName: "arrow.down.doc.fill")
                .foregroundStyle(.white)
                .font(.system(size: 18))
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
