import SwiftUI
import UIKit

struct NOVAHomeView: View {

    @StateObject private var store = NOVAStoreService.shared
    @EnvironmentObject private var repositories: RepositoryStore

    @State private var bannerPage: NOVABanner?      // يتحكم فقط بالتمرير بين البنرات
    @State private var selectedBanner: NOVABanner?  // يفتح الشيت عند الضغط الفعلي
    @State private var selectedApp: RepoApp?
    @State private var didInitialRefresh = false     // تمنع التحميل المتكرر عند التنقل

    // MARK: - Palette

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // سحب "آخر التحديثات" من المصادر المضافة (مثل AppTesters)
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
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if store.isLoading && store.apps.isEmpty && !didInitialRefresh {
                    ProgressView("جاري التحميل...")
                        .tint(gradientStart)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            header

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
                // منع التحميل المتكرر عند التنقل
                guard !didInitialRefresh else { return }

                await store.refresh()

                // انتظار تحميل الكاش الخاص بالسورسات لتظهر التطبيقات مباشرة
                while !repositories.catalogCacheLoaded {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }

                if latestApps.isEmpty {
                    await refreshRepositoryCatalogs()
                }

                didInitialRefresh = true
            }
            .onChange(of: store.banners) { banners in
                if bannerPage == nil { bannerPage = banners.first }
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
            VStack(alignment: .leading, spacing: 5) {
                Text(store.settings?.name ?? "NOVA STORE")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(brandGradient)

                Text("متجرك للتطبيقات والألعاب")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Haptics.impact()
                Task {
                    await store.refresh(force: true)
                    await refreshRepositoryCatalogs()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(gradientStart)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial)
                    .overlay(Circle().stroke(brandGradient.opacity(0.35), lineWidth: 1))
                    .clipShape(Circle())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Banners

    private var bannersSection: some View {
        VStack(spacing: 10) {
            TabView(selection: $bannerPage) {
                ForEach(store.banners) { banner in
                    BannerCard(banner: banner) {
                        Haptics.tap()
                        selectedBanner = banner
                    }
                    .tag(Optional(banner))
                    .padding(.horizontal, 16)
                }
            }
            .frame(height: 300)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onAppear { if bannerPage == nil { bannerPage = store.banners.first } }

            if store.banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(store.banners) { banner in
                        Capsule()
                            .fill(
                                banner.id == bannerPage?.id
                                    ? AnyShapeStyle(brandGradient)
                                    : AnyShapeStyle(Color.secondary.opacity(0.25))
                            )
                            .frame(width: banner.id == bannerPage?.id ? 20 : 6, height: 6)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: bannerPage)
            }
        }
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

    @ViewBuilder
    private func installPill(_ app: RepoApp) -> some View {
        if repositories.activeDownloadID == app.id {
            ProgressView()
                .tint(.white)
                .frame(width: 72, height: 32)
                .background(brandGradient)
                .clipShape(Capsule())
        } else {
            Button {
                Haptics.impact()
                Task { await repositories.download(app) }
            } label: {
                Text("تثبيت")
                    .font(.system(size: 12.5, weight: .bold))
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

    // MARK: - Banner Destination

    @ViewBuilder
    private func bannerDestination(_ banner: NOVABanner) -> some View {
        if let appID = banner.appID, let app = store.app(id: appID) {
            NOVAAppDetailView(app: app)
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

// MARK: - Press animation & haptics (مشتركة بأسلوب الصفحة الرئيسية)

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

private enum Haptics {
    static func tap() { UISelectionFeedbackGenerator().selectionChanged() }
    static func impact() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}

// MARK: - Banner Card (تصميم "زد ساين": النص والزر فوق الصورة مباشرة)

private struct BannerCard: View {
    let banner: NOVABanner
    let action: () -> Void

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd],
                        startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    // الصورة تملأ الكرت بالكامل
                    AsyncImage(url: URL(string: banner.imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            LinearGradient(
                                colors: [gradientStart.opacity(0.5), gradientEnd.opacity(0.35)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                    // تظليل تدريجي أسفل الصورة لضمان وضوح النص
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.1), .black.opacity(0.72)],
                        startPoint: .top, endPoint: .bottom
                    )

                    // النص والزر فوق الصورة مباشرة
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
        }
        .buttonStyle(PressableStyle())
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
