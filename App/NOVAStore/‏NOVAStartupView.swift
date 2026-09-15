import SwiftUI
import UIKit

/// شاشة البداية الخاصة بـ NOVA STORE.
/// تبقى 3 ثوانٍ كحد أدنى، وخلالها يتم تحميل بيانات المتجر وصور البنرات
/// وأيقونات التطبيقات في الخلفية. لا تعدّل NOVAHomeView.
struct NOVAStartupView<Content: View>: View {
    private let content: () -> Content
    @State private var finished = false
    @State private var didStart = false

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            if finished { content().transition(.opacity) }
            else { NOVAStartupSplash().transition(.opacity) }
        }
        .task {
            guard !didStart else { return }
            didStart = true
            let preloadTask = Task { await NOVAStartupPreloader.preload() }

            // الشاشة ثابتة 3 ثوانٍ ولا تنتظر الشبكة.
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            // يواصل التحميل بالخلفية إذا لم يكتمل بعد.
            _ = preloadTask

            withAnimation(.easeOut(duration: 0.25)) {
                finished = true
            }
        }
    }
}

private struct NOVAStartupSplash: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "5B21B6"), Color(hex: "7C3AED"), Color(hex: "A855F7")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 330, height: 330)
                .blur(radius: 8)
                .scaleEffect(pulse ? 1.12 : 0.94)

            VStack(spacing: 22) {
                Image("NOVAStoreLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: .black.opacity(0.24), radius: 28, y: 14)
                    .scaleEffect(pulse ? 1.02 : 0.96)

                VStack(spacing: 7) {
                    Text("NOVA STORE")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white)

                    Text("جاري تجهيز المتجر...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.05)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

@MainActor
private enum NOVAStartupPreloader {
    static func preload() async {
        await NOVAStoreService.shared.refresh(force: true)
        let store = NOVAStoreService.shared
        var urls: [URL] = []
        urls += store.banners.compactMap { URL(string: $0.imageURL) }
        for app in store.apps {
            if let icon = URL(string: app.icon) { urls.append(icon) }
            urls += app.screenshots.compactMap(URL.init(string:))
        }
        var seen = Set<String>()
        let unique = urls.filter { seen.insert($0.absoluteString).inserted }
        await withTaskGroup(of: Void.self) { group in
            for url in unique.prefix(80) {
                group.addTask { await fetchAndWarm(url) }
            }
        }
    }

    private static func fetchAndWarm(_ url: URL) async {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 12
        _ = try? await URLSession.shared.data(for: request)
    }
}
