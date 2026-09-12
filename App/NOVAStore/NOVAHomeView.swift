import SwiftUI
import UIKit
import AudioToolbox

struct NOVAHomeView: View {

    @StateObject private var store = NOVAStoreService.shared
    @EnvironmentObject private var repositories: RepositoryStore

    @State private var bannerOrder: [NOVABanner] = []
    @State private var dragOffset: CGSize = .zero
    @State private var selectedBanner: NOVABanner?
    @State private var selectedApp: RepoApp?
    @State private var didInitialRefresh = false

    // MARK: - Palette

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var latestApps: [RepoApp] {
        let limit = store.settings?.latestAppsLimit ?? 10
        var seen = Set<String>()
        var result: [RepoApp] = []
        for repo in repositories.repositories {
            guard let apps = repositories.catalog[repo.id]?.apps else { continue }
            for app in apps where seen.insert(app.id).inserted {
                result.append(app)
                if result.count >= max(0, limit) { return result }
            }
        }
        for novaApp in store.apps where novaApp.enabled {
            guard result.count < max(0, limit) else { break }
            let app = RepoApp(novaApp: novaApp)
            if seen.insert(app.id).inserted { result.append(app) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if store.isLoading && store.apps.isEmpty && !didInitialRefresh {
                    VStack(spacing: 16) {
                        ModernPulseLoadingView(color: gradientStart)
                        Text("جاري التحميل...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            header // الهيدر بتأثير الليزر والانترو القوي

                            if !store.banners.isEmpty {
                                bannersSection
                            }

                            latestAppsSection
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        Haptics.tap()
                        await store.refresh(force: true)
                        await refreshRepositoryCatalogs()
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                guard !didInitialRefresh else { return }

                await store.refresh()

                while !repositories.catalogCacheLoaded {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }

                if latestApps.isEmpty {
                    await refreshRepositoryCatalogs()
                }

                didInitialRefresh = true
            }
            .onChange(of: store.banners) { banners in
                if bannerOrder.map(\.id) != banners.map(\.id) {
                    bannerOrder = banners
                }
            }
            .sheet(item: $selectedBanner) { banner in
                bannerDestination(banner)
            }
            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }
        }
        .tint(gradientStart)
    }

    private func refreshRepositoryCatalogs() async {
        await withTaskGroup(of: Void.self) { group in
            for repo in repositories.repositories {
                group.addTask { await repositories.refresh(repo) }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            
            // استدعاء تأثير الانترو الليزري الاحترافي
            LaserIntroTitleView(text: store.settings?.name ?? "NOVA STORE")
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .overlay(
            HStack {
                Spacer()
                Button {
                    Haptics.impact()
                    Task {
                        await store.refresh(force: true)
                        await refreshRepositoryCatalogs()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(gradientStart)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 16)
        )
    }

    // MARK: - Banners

    private var backLayers: [NOVABanner] {
        Array(bannerOrder.dropFirst().prefix(2))
    }

    private var bannersSection: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(Array(backLayers.enumerated()), id: \.element.id) { offset, banner in
                    let depth = offset + 1
                    BannerCard(banner: banner)
                        .id(banner.id) 
                        .frame(height: 300)
                        .padding(.horizontal, 16)
                        .scaleEffect(1 - CGFloat(depth) * 0.045)
                        .offset(y: -CGFloat(depth) * 14)
                        .opacity(1 - Double(depth) * 0.25)
                        .allowsHitTesting(false)
                }

                if let front = bannerOrder.first {
                    BannerCard(banner: front)
                        .id("front-\(front.id)") 
                        .frame(height: 300)
                        .padding(.horizontal, 16)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                        .gesture(
                            DragGesture(minimumDistance: 12)
                                .onChanged { value in dragOffset = value.translation }
                                .onEnded(handleSwipeEnd)
                        )
                        .onTapGesture {
                            guard dragOffset == .zero else { return }
                            Haptics.tap()
                            selectedBanner = front
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: dragOffset)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: bannerOrder)

            if store.banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(store.banners) { banner in
                        Capsule()
                            .fill(
                                banner.id == bannerOrder.first?.id
                                    ? AnyShapeStyle(brandGradient)
                                    : AnyShapeStyle(Color.secondary.opacity(0.25))
                            )
                            .frame(width: banner.id == bannerOrder.first?.id ? 20 : 6, height: 6)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: bannerOrder)
            }
        }
        .onAppear {
            if bannerOrder.isEmpty { bannerOrder = store.banners }
        }
    }

    private func handleSwipeEnd(_ value: DragGesture.Value) {
        let threshold: CGFloat = 90
        if abs(value.translation.width) > threshold, bannerOrder.count > 1 {
            Haptics.impact()
            var order = bannerOrder
            let moved = order.removeFirst()
            order.append(moved)
            bannerOrder = order
        }
        dragOffset = .zero
    }

    // MARK: - Latest Apps

    private var latestAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("آخر التحديثات")
                    .font(.title3.weight(.bold))

                Spacer()

                Text("\(latestApps.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(brandGradient)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)

            if latestApps.isEmpty {
                emptyAppsView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(latestApps) { app in
                        appRow(app)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var emptyAppsView: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(brandGradient.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(brandGradient)
            }
            Text("لا توجد تطبيقات حالياً")
                .font(.headline)
            Text("قم بإضافة مصادر لتظهر التطبيقات هنا.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    @ViewBuilder
    private func appRow(_ app: RepoApp) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                selectedApp = app
            } label: {
                HStack(spacing: 13) {
                    CachedAppIcon(url: app.iconURL, size: 56, cornerRadius: 15)
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(brandGradient.opacity(0.3), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let dev = app.developerName, !dev.isEmpty {
                            Text(dev)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 7) {
                            if let version = app.version, !version.isEmpty {
                                Text("v\(version)")
                            }
                            if let size = app.size {
                                Text("•")
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            }
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Spacer(minLength: 4)

            installPill(app)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(brandGradient.opacity(0.12), lineWidth: 1)
        }
    }
    
    // MARK: - Install Button
    
    @ViewBuilder
    private func installPill(_ app: RepoApp) -> some View {
        if repositories.activeDownloadID == app.id {
            ModernPulseLoadingView(color: .white)
                .frame(width: 72, height: 32)
                .background(brandGradient)
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
        } else {
            Button {
                Haptics.installSoundAndImpact()
                Task { await repositories.download(app) }
            } label: {
                Text("تثبيت")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 32)
                    .background(
                        app.downloadURL == nil
                            ? AnyShapeStyle(Color.gray.opacity(0.4))
                            : AnyShapeStyle(brandGradient)
                    )
                    .clipShape(Capsule())
                    .shadow(color: gradientStart.opacity(app.downloadURL == nil ? 0 : 0.3), radius: 5, y: 2)
            }
            .buttonStyle(PressableStyle())
            .disabled(app.downloadURL == nil || repositories.activeDownloadID != nil)
        }
    }

    @ViewBuilder
    private func bannerDestination(_ banner: NOVABanner) -> some View {
        if let appID = banner.appID, let app = store.app(id: appID) {
            RepoAppDetailSheet(app: RepoApp(novaApp: app))
        } else if !banner.externalURL.isEmpty {
            BannerExternalDestination(urlString: banner.externalURL)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("لا يوجد محتوى مرتبط بهذا البنر")
                    .font(.headline)
            }
            .padding()
        }
    }
}

// MARK: - Laser Intro Title Effect (تأثير انترو ليزري احترافي)

private struct LaserIntroTitleView: View {
    let text: String
    @State private var progress: CGFloat = 0.0
    @State private var glitchOffset: CGFloat = 0.0

    // خط إنجليزي قوي وهجومي يعطي طابع الجيمينج والانتروهات
    private let customFont = Font.custom("AvenirNext-HeavyItalic", size: 36)

    var body: some View {
        ZStack(alignment: .leading) {
            // 1. النص الخلفي الباهت جداً كقاعدة
            Text(text)
                .font(customFont)
                .foregroundStyle(Color.gray.opacity(0.12))

            // 2. النص الملون اللي يظهر مع الليزر
            ZStack(alignment: .leading) {
                // ظل سيان للـ Glitch
                Text(text)
                    .font(customFont)
                    .foregroundColor(.cyan)
                    .offset(x: glitchOffset, y: -glitchOffset * 0.4)
                    .opacity(0.8)

                // ظل وردي للـ Glitch
                Text(text)
                    .font(customFont)
                    .foregroundColor(Color(hex: "FF00FF"))
                    .offset(x: -glitchOffset, y: glitchOffset * 0.4)
                    .opacity(0.8)

                // النص الأصلي المتدرج
                Text(text)
                    .font(customFont)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "7C3AED"), Color(hex: "A855F7"), .white],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
            .mask(
                // القناع اللي يخلي النص يظهر مع تقدم الليزر
                GeometryReader { geo in
                    Rectangle()
                        .frame(width: max(0, geo.size.width * progress))
                }
            )

            // 3. شعاع الليزر القوي (الماسح)
            GeometryReader { geo in
                ZStack {
                    // توهج الليزر (Blur)
                    Capsule()
                        .fill(Color.cyan)
                        .frame(width: 24, height: 48)
                        .blur(radius: 8)
                    
                    // قلب الليزر الأبيض الساطع
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 4, height: 44)
                        .shadow(color: .white, radius: 4, x: 0, y: 0)
                        .shadow(color: Color(hex: "7C3AED"), radius: 12, x: 0, y: 0)
                }
                .offset(x: (geo.size.width * progress) - 12, y: -3) // توسيط الليزر على حرف النص
                .opacity(progress > 0.02 && progress < 0.98 ? 1 : 0) // يختفي في البداية والنهاية
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            // حركة الليزر ذهاباً وإياباً (يكتب ويمسح)
            withAnimation(.easeInOut(duration: 2.2).delay(0.4).repeatForever(autoreverses: true)) {
                progress = 1.0
            }
            // تأثير الجليتش (هزة خفيفة عشوائية)
            Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                if progress > 0.1 && progress < 0.9 && Int.random(in: 0...10) > 8 {
                    glitchOffset = CGFloat.random(in: 3...5)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        glitchOffset = 0
                    }
                }
            }
        }
    }
}

// MARK: - Modern Pulse Loading View

private struct ModernPulseLoadingView: View {
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 4.5, height: isAnimating ? 16 : 6)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Banner Image Caching System (حماية MainActor لمنع الكراش)

@MainActor
class BannerImageLoader: ObservableObject {
    @Published var image: UIImage?
    private static let cache = NSCache<NSString, UIImage>()

    func load(from urlString: String) {
        if let cached = Self.cache.object(forKey: urlString as NSString) {
            self.image = cached
            return
        }
        
        self.image = nil
        
        guard let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let uiImage = UIImage(data: data) else { return }
                Self.cache.setObject(uiImage, forKey: urlString as NSString)
                self.image = uiImage
            } catch {
                // خطأ صامت
            }
        }
    }
}

private struct CachedBannerImage: View {
    let urlString: String
    @StateObject private var loader = BannerImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(hex: "F3E8FF")
                    ModernPulseLoadingView(color: Color(hex: "7C3AED"))
                }
            }
        }
        .onAppear {
            loader.load(from: urlString)
        }
        .onChange(of: urlString) { newURL in
            loader.load(from: newURL)
        }
    }
}

// MARK: - Banner Card

private struct BannerCard: View {
    let banner: NOVABanner

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd],
                        startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                
                CachedBannerImage(urlString: banner.imageURL)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.1), .black.opacity(0.72)],
                    startPoint: .top, endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 12) {
                    if !banner.buttonTitle.isEmpty {
                        Text(banner.buttonTitle)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(brandGradient)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    }

                    Spacer(minLength: 6)

                    VStack(alignment: .trailing, spacing: 4) {
                        if !banner.subtitle.isEmpty {
                            Text(banner.subtitle)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Text(banner.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                        if !banner.description.isEmpty {
                            Text(banner.description)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.28), .clear],
                                   startPoint: .top, endPoint: .center),
                    lineWidth: 1
                )
        }
        .shadow(color: gradientStart.opacity(0.25), radius: 14, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Press animation & haptics

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

@MainActor
private enum Haptics {
    static func tap() { UISelectionFeedbackGenerator().selectionChanged() }
    static func impact() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    
    static func installSoundAndImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        AudioServicesPlaySystemSound(1407) 
    }
}

// MARK: - External Destination

private struct BannerExternalDestination: View {
    let urlString: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "link")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                Text("فتح الرابط")
                    .font(.headline)
                if let url = URL(string: urlString), !urlString.isEmpty {
                    Link("فتح", destination: url)
                        .buttonStyle(.borderedProminent)
                } else {
                    Text("لا يوجد رابط صالح لهذا البنر.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("NOVA STORE")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
