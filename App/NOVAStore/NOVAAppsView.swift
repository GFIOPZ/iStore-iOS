import SwiftUI
import UIKit

/// NOVA STORE — premium applications catalog.
///
/// The view keeps the existing RepositoryStore/NOVAStoreService data pipeline,
/// but gives the catalog a cleaner storefront layout with a subtle scroll-wave
/// motion effect. The motion is implemented with GeometryReader so it remains
/// compatible with the project's iOS 16.4 deployment target.
struct NOVAAppsView: View {

    @EnvironmentObject private var store: RepositoryStore
    @StateObject private var manualApps = NOVAStoreService.shared

    @State private var searchText = ""
    @State private var selectedApp: RepoApp?
    @State private var isRefreshing = false

    private let gradientStart = Color(hex: "6D28D9")
    private let gradientMid = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientMid, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Every app from every added repository plus every enabled app from
    /// NOVA-STORE/apps.json. Duplicate bundle IDs are shown only once.
    private var allApps: [RepoApp] {
        var seen = Set<String>()
        var result: [RepoApp] = []

        for repo in store.repositories {
            guard let apps = store.catalog[repo.id]?.apps else { continue }

            for app in apps where seen.insert(app.id).inserted {
                result.append(app)
            }
        }

        for novaApp in manualApps.apps where novaApp.enabled {
            let app = RepoApp(novaApp: novaApp)

            if seen.insert(app.id).inserted {
                result.append(app)
            }
        }

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var filteredApps: [RepoApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !q.isEmpty else {
            return allApps
        }

        return allApps.filter { app in
            app.name.localizedCaseInsensitiveContains(q) ||
            (app.developerName?.localizedCaseInsensitiveContains(q) ?? false) ||
            (app.localizedDescription?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var hasAnySource: Bool {
        !store.repositories.isEmpty || !manualApps.apps.isEmpty
    }

    private var isLoadingInitially: Bool {
        (isRefreshing || manualApps.isLoading) && allApps.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                storefrontBackground

                if isLoadingInitially {
                    loadingState
                } else if !hasAnySource {
                    emptyState(
                        icon: "shippingbox",
                        title: "لا توجد مصادر مضافة",
                        message: "أضف مصدرًا من قسم المصادر لتظهر التطبيقات هنا تلقائيًا."
                    )
                } else if filteredApps.isEmpty {
                    emptyState(
                        icon: searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass",
                        title: searchText.isEmpty ? "لا توجد تطبيقات حالياً" : "لا توجد نتائج",
                        message: searchText.isEmpty
                            ? "اسحب للأسفل لتحديث المتجر."
                            : "جرّب البحث باسم تطبيق آخر."
                    )
                } else {
                    catalog
                }
            }
            .navigationBarHidden(true)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "ابحث عن تطبيق"
            )
            .task {
                if manualApps.apps.isEmpty {
                    await manualApps.refresh()
                }

                if allApps.isEmpty {
                    await refreshAll()
                }
            }
            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }
        }
        .tint(gradientMid)
    }

    // MARK: - Storefront

    private var storefrontBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Circle()
                .fill(gradientEnd.opacity(0.09))
                .frame(width: 300, height: 300)
                .blur(radius: 55)
                .offset(x: 150, y: -260)

            Circle()
                .fill(gradientStart.opacity(0.06))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -150, y: 300)
        }
    }

    private var catalog: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                storeHeader

                if !searchText.isEmpty {
                    searchResultCaption
                }

                ForEach(filteredApps) { app in
                    NOVAWaveAppCard(
                        app: app,
                        brandGradient: brandGradient,
                        onOpen: {
                            Haptics.tap()
                            selectedApp = app
                        },
                        onInstall: {
                            Haptics.impact()
                            Task {
                                await store.download(app)
                            }
                        },
                        isInstalling: store.activeDownloadID == app.id,
                        isAnyDownloadActive: store.activeDownloadID != nil
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .coordinateSpace(name: "NOVAStoreScroll")
        .scrollIndicators(.hidden)
        .refreshable {
            await refreshAll(force: true)
        }
    }

    private var storeHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("NOVA STORE")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gradientStart, gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack(spacing: 6) {
                    Circle()
                        .fill(gradientEnd)
                        .frame(width: 6, height: 6)

                    Text("\(filteredApps.count) تطبيق")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 10)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(gradientEnd.opacity(0.20), lineWidth: 0.8)

                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(brandGradient)
            }
            .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var searchResultCaption: some View {
        HStack {
            Text("نتائج البحث")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(filteredApps.count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(gradientMid)
        }
        .padding(.horizontal, 4)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gradientEnd.opacity(0.10))
                    .frame(width: 76, height: 76)

                ProgressView()
                    .tint(gradientMid)
                    .scaleEffect(1.15)
            }

            Text("جاري تجهيز المتجر...")
                .font(.system(size: 15, weight: .semibold))

            Text("يتم تحميل التطبيقات والصور بأمان")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Refresh

    /// Refreshes repository catalogs and the NOVA-STORE catalog concurrently.
    private func refreshAll(force: Bool = false) async {
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: Void.self) { group in
            for repo in store.repositories {
                group.addTask {
                    await store.refresh(repo)
                }
            }

            group.addTask {
                if force {
                    await manualApps.forceRefresh()
                } else {
                    await manualApps.refresh()
                }
            }
        }
    }

    // MARK: - Empty

    @ViewBuilder
    private func emptyState(
        icon: String,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(gradientEnd.opacity(0.12))
                    .frame(width: 86, height: 86)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(brandGradient)
            }

            Text(title)
                .font(.system(size: 17, weight: .bold))

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(gradientEnd.opacity(0.18), lineWidth: 0.8)
        }
        .padding(22)
    }
}

// MARK: - Animated App Card

private struct NOVAWaveAppCard: View {
    let app: RepoApp
    let brandGradient: LinearGradient
    let onOpen: () -> Void
    let onInstall: () -> Void
    let isInstalling: Bool
    let isAnyDownloadActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("NOVAStoreScroll"))
            let center = UIScreen.main.bounds.height * 0.48
            let distance = abs(frame.midY - center)
            let normalized = min(distance / 520, 1)
            let direction: CGFloat = frame.midY < center ? -1 : 1

            let wave = reduceMotion
                ? 0
                : sin(Double(frame.midY / 115)) * 4.5 * (1 - normalized)

            let scale = reduceMotion
                ? 1
                : 0.965 + (0.035 * (1 - normalized))

            let rotation = reduceMotion
                ? 0
                : Double(direction * normalized * 1.8)

            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        CachedAppIcon(
                            url: app.iconURL,
                            size: 62,
                            cornerRadius: 17
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(
                                    brandGradient.opacity(0.24),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(
                            color: Color(hex: "7C3AED").opacity(0.13),
                            radius: 10,
                            y: 5
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(app.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            HStack(spacing: 7) {
                                if let version = app.version, !version.isEmpty {
                                    Text("v\(version)")
                                }

                                if let size = app.size {
                                    Circle()
                                        .fill(.secondary.opacity(0.55))
                                        .frame(width: 3, height: 3)

                                    Text(
                                        ByteCountFormatter.string(
                                            fromByteCount: size,
                                            countStyle: .file
                                        )
                                    )
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                            if let developer = app.developerName,
                               !developer.isEmpty {
                                Text(developer)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary.opacity(0.82))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())

                installButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.70),
                                Color(hex: "A855F7").opacity(0.16),
                                Color(hex: "7C3AED").opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            }
            .shadow(
                color: Color(hex: "7C3AED").opacity(0.07),
                radius: 18,
                y: 7
            )
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .offset(x: wave)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.34, dampingFraction: 0.84),
                value: frame.midY
            )
        }
        .frame(height: 92)
    }

    private var installButton: some View {
        Button(action: onInstall) {
            ZStack {
                if isInstalling {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("تثبيت")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: 78, height: 38)
            .background {
                Capsule()
                    .fill(
                        app.downloadURL == nil
                            ? AnyShapeStyle(Color.gray.opacity(0.42))
                            : AnyShapeStyle(brandGradient)
                    )
            }
            .shadow(
                color: app.downloadURL == nil
                    ? .clear
                    : Color(hex: "7C3AED").opacity(0.30),
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(
            app.downloadURL == nil ||
            (isAnyDownloadActive && !isInstalling)
        )
    }
}

// MARK: - Press animation

private struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion
                    ? 0.95
                    : 1
            )
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.22, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

private enum Haptics {
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

#Preview {
    NOVAAppsView()
        .environmentObject(RepositoryStore())
}
