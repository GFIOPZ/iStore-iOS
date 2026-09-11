import SwiftUI
import UIKit

struct NOVAAppsView: View {

    @EnvironmentObject private var store: RepositoryStore
    @State private var searchText = ""
    @State private var selectedApp: RepoApp?
    @State private var isRefreshing = false
    @State private var didInitialRefresh = false // تمنع التحميل المتكرر عند التنقل

    // MARK: - Palette

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var allApps: [RepoApp] {
        var seen = Set<String>()
        var result: [RepoApp] = []
        for repo in store.repositories {
            guard let apps = store.catalog[repo.id]?.apps else { continue }
            for app in apps {
                if !seen.contains(app.id) {
                    seen.insert(app.id)
                    result.append(app)
                }
            }
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var filteredApps: [RepoApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return allApps }
        return allApps.filter { app in
            let searchString = [app.name, app.developerName, app.localizedDescription]
                .compactMap { $0 }
                .joined(separator: " ")
            return searchString.localizedCaseInsensitiveContains(q)
        }
    }

    private var hasAnyRepositories: Bool { !store.repositories.isEmpty }
    private var isLoadingInitially: Bool { isRefreshing && allApps.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoadingInitially && !didInitialRefresh {
                    ProgressView("جاري تحميل التطبيقات...")
                        .tint(gradientStart)

                } else if !hasAnyRepositories {
                    emptyState(
                        icon: "shippingbox",
                        title: "لا توجد مصادر مضافة",
                        message: "أضف مصدرًا من قسم \"المصادر\" لتظهر تطبيقاته هنا تلقائيًا."
                    )

                } else if filteredApps.isEmpty {
                    emptyState(
                        icon: "square.grid.2x2",
                        title: searchText.isEmpty ? "لا توجد تطبيقات حالياً" : "لا توجد نتائج",
                        message: searchText.isEmpty
                            ? "اسحب للأسفل لتحديث المصادر."
                            : "جرّب البحث باسم تطبيق آخر."
                    )

                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredApps) { app in
                                appRow(app)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 20)
                    }
                    .refreshable { await refreshAll() }
                }
            }
            .navigationTitle("NOVA STORE")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "ابحث عن تطبيق"
            )
            .task { 
                guard !didInitialRefresh else { return }
                
                // انتظار تحميل الكاش من المصادر
                while !store.catalogCacheLoaded {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                
                if allApps.isEmpty { 
                    await refreshAll() 
                }
                
                didInitialRefresh = true
            }
            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }
        }
        .tint(gradientStart)
    }

    private func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: Void.self) { group in
            for repo in store.repositories {
                group.addTask { await store.refresh(repo) }
            }
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(brandGradient.opacity(0.14))
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(brandGradient)
            }
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Row

    @ViewBuilder
    private func appRow(_ app: RepoApp) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                selectedApp = app
            } label: {
                HStack(spacing: 12) {
                    CachedAppIcon(url: app.iconURL, size: 54, cornerRadius: 14)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(brandGradient.opacity(0.35), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let version = app.version, !version.isEmpty {
                                Text("v\(version)")
                            }
                            if let size = app.size {
                                Text("•")
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            }
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Spacer(minLength: 4)

            installPill(app)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thickMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(brandGradient.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: gradientStart.opacity(0.08), radius: 10, y: 4)
    }

    @ViewBuilder
    private func installPill(_ app: RepoApp) -> some View {
        if store.activeDownloadID == app.id {
            ProgressView()
                .tint(.white)
                .frame(width: 78, height: 34)
                .background(brandGradient)
                .clipShape(Capsule())
        } else {
            Button {
                Haptics.impact()
                Task { await store.download(app) }
            } label: {
                Text("تثبيت")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 34)
                    .background(
                        app.downloadURL == nil
                            ? AnyShapeStyle(Color.gray.opacity(0.4))
                            : AnyShapeStyle(brandGradient)
                    )
                    .clipShape(Capsule())
                    .shadow(color: gradientStart.opacity(app.downloadURL == nil ? 0 : 0.35), radius: 6, y: 3)
            }
            .buttonStyle(PressableStyle())
            .disabled(app.downloadURL == nil || store.activeDownloadID != nil)
        }
    }
}

// MARK: - Press animation

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
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
