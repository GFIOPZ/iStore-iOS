import SwiftUI

/// "التطبيقات" tab — no longer depends on the separate NOVA-STORE control
/// panel (apps.json). Instead it aggregates the catalogs of every repository
/// already added in RepositoryStore (AppTesters, SwiftSource, etc.) into one
/// searchable list, exactly like the existing per-source browser in
/// SourcesView, just merged across all sources.
struct NOVAAppsView: View {

    @EnvironmentObject private var store: RepositoryStore
    @State private var searchText = ""
    @State private var selectedApp: RepoApp?
    @State private var isRefreshing = false

    /// Every app from every added source, de-duplicated by bundle id (or name
    /// when the id is empty) and sorted alphabetically.
    private var allApps: [RepoApp] {
        var seen = Set<String>()
        var result: [RepoApp] = []
        for repo in store.repositories {
            guard let apps = store.catalog[repo.id]?.apps else { continue }
            for app in apps where seen.insert(app.id).inserted {
                result.append(app)
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
            app.name.localizedCaseInsensitiveContains(q) ||
            (app.developerName?.localizedCaseInsensitiveContains(q) ?? false) ||
            (app.localizedDescription?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var hasAnyRepositories: Bool { !store.repositories.isEmpty }

    private var isLoadingInitially: Bool {
        isRefreshing && allApps.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoadingInitially {
                    ProgressView("جاري تحميل التطبيقات...")

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
                                Button {
                                    selectedApp = app
                                } label: {
                                    appRow(app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
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
                if allApps.isEmpty { await refreshAll() }
            }
            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }
        }
    }

    /// Refreshes every added repository concurrently. One failing source
    /// never blocks the others — each repo keeps its own fetchError.
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
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title).font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    @ViewBuilder
    private func appRow(_ app: RepoApp) -> some View {
        HStack(spacing: 14) {
            CachedAppIcon(url: app.iconURL, size: 64, cornerRadius: 16)

            VStack(alignment: .leading, spacing: 5) {
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

                HStack(spacing: 8) {
                    if let version = app.version, !version.isEmpty {
                        Text("v\(version)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let size = app.size {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    NOVAAppsView()
        .environmentObject(RepositoryStore())
}
