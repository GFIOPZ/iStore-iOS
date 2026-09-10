import SwiftUI

/// Zed Store — Purple storefront
struct AppsView: View {

    @EnvironmentObject private var repositories: RepositoryStore
    @Environment(\.forgeTheme) private var T
    @Environment(\.layoutDirection) private var layoutDirection

    @AppStorage("app.language")
    private var languageCode = AppLanguage.english.rawValue

    @State private var selectedApp: RepoApp?
    @State private var searchText = ""
    @State private var displayedApps: [RepoApp] = []
    @State private var didInitialRefresh = false

    @FocusState private var searchFieldFocused: Bool

    private var allApps: [RepoApp] {
        repositories.repositories.flatMap { repo in
            repositories.catalog[repo.id]?.apps ?? []
        }
    }

    private func refreshDisplayedApps() {

        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            displayedApps = allApps
            return
        }

        displayedApps = allApps.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            (app.developerName?
                .localizedCaseInsensitiveContains(query) ?? false) ||
            (app.localizedDescription?
                .localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {

        NavigationStack {

            ZStack {

                ScrollView {

                    LazyVStack(
                        spacing: 0,
                        pinnedViews: [.sectionHeaders]
                    ) {

                        Section {

                            if displayedApps.isEmpty {

                                emptyState

                            } else {

                                ForEach(
                                    displayedApps.indices,
                                    id: \.self
                                ) { index in

                                    appRow(displayedApps[index])
                                        .padding(.horizontal, T.pad)
                                        .padding(.bottom, 13)
                                        .transaction { transaction in
                                            transaction.animation = nil
                                        }
                                }
                            }

                        } header: {

                            VStack(spacing: 0) {

                                titleHeader

                                searchBar
                                    .padding(.horizontal, T.pad)
                                    .padding(.bottom, 13)
                            }
                            .background {
                                Color.white.opacity(
                                    T.isDark ? 0.88 : 0.94
                                )
                                .overlay {
                                    LinearGradient(
                                        colors: [
                                            T.accentSoft,
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                            }
                            .overlay(
                                Rectangle()
                                    .fill(T.accent.opacity(0.12))
                                    .frame(height: 1),
                                alignment: .bottom
                            )
                            .zIndex(2)
                        }
                    }
                    .padding(.bottom, 40)
                }

                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .scrollContentBackground(.hidden)
                .background {
                    ForgeBackdrop()
                }
                .toolbar(.hidden, for: .navigationBar)

                // Purple top glow
                .overlay(alignment: .top) {

                    LinearGradient(
                        colors: [
                            T.accent.opacity(0.18),
                            T.accentSoft.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }

                .task {

                    guard !didInitialRefresh else {
                        return
                    }

                    while !repositories.catalogCacheLoaded {
                        try? await Task.sleep(
                            nanoseconds: 20_000_000
                        )
                    }

                    refreshDisplayedApps()

                    didInitialRefresh = true

                    await refreshAll()

                    refreshDisplayedApps()
                }

                .refreshable {

                    await refreshAll()
                    refreshDisplayedApps()
                }

                .task(id: searchText) {

                    do {
                        try await Task.sleep(
                            nanoseconds: 120_000_000
                        )
                    } catch {
                        return
                    }

                    guard !Task.isCancelled else {
                        return
                    }

                    refreshDisplayedApps()
                }
            }

            .contentShape(Rectangle())

            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }

            .alert(
                languageCode == AppLanguage.arabic.rawValue
                    ? "تعذر تثبيت التطبيق"
                    : "App Installation Failed",

                isPresented: Binding(

                    get: {
                        repositories.downloadError != nil ||
                        repositories.installError != nil
                    },

                    set: { isPresented in

                        if !isPresented {
                            repositories.downloadError = nil
                            repositories.installError = nil
                        }
                    }
                )

            ) {

                Button(
                    languageCode == AppLanguage.arabic.rawValue
                        ? "حسناً"
                        : "OK",
                    role: .cancel
                ) {

                    repositories.downloadError = nil
                    repositories.installError = nil
                }

            } message: {

                Text(
                    repositories.downloadError ??
                    repositories.installError ??
                    ""
                )
            }
        }
    }

    // MARK: - Refresh

    private func refreshAll() async {

        let repos = repositories.repositories

        await withTaskGroup(of: Void.self) { group in

            for repo in repos {

                group.addTask {
                    await repositories.refresh(repo)
                }
            }
        }
    }

    // MARK: - Header

    private var titleHeader: some View {

        VStack(spacing: 4) {

            Text("Zed Store")
                .font(
                    .system(
                        size: 38,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            T.accentHi,
                            T.accent,
                            T.accentDeep
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .tracking(-1.0)

            Text(
                languageCode == AppLanguage.arabic.rawValue
                    ? "متجر التطبيقات والألعاب"
                    : "Apps & Games Store"
            )
            .font(T.sans(12, .semibold))
            .foregroundColor(T.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 15)
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: - Search

    private var searchBar: some View {

        HStack(spacing: 9) {

            searchIcon

            searchField
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 14)
        .frame(height: 46)

        .background {

            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(
                T.isDark
                    ? Color.white.opacity(0.06)
                    : Color.white.opacity(0.92)
            )
        }

        .overlay {

            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                T.accent.opacity(0.28),
                lineWidth: 1
            )
        }

        .shadow(
            color: T.accent.opacity(0.08),
            radius: 14,
            x: 0,
            y: 5
        )
    }

    private var searchIcon: some View {

        Button {

            searchFieldFocused = false

        } label: {

            ZStack {

                Circle()
                    .fill(T.accentSoft)
                    .frame(width: 32, height: 32)

                Image(systemName: "magnifyingglass")
                    .font(
                        .system(
                            size: 14,
                            weight: .bold
                        )
                    )
                    .foregroundColor(T.accent)
            }
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {

        let isArabic =
            languageCode == AppLanguage.arabic.rawValue

        let textAlignment: TextAlignment =
            isArabic ? .trailing : .leading

        let frameAlignment: Alignment =
            isArabic ? .trailing : .leading

        let placeholder =
            isArabic
                ? "ألعاب وتطبيقات والمزيد"
                : "Games, apps and more"

        return ZStack(
            alignment: frameAlignment
        ) {

            if searchText.isEmpty {

                Text(placeholder)
                    .font(T.sans(14, .semibold))
                    .foregroundColor(
                        T.accent.opacity(0.50)
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .allowsHitTesting(false)
            }

            TextField(
                "",
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(T.sans(15, .semibold))
            .foregroundColor(
                T.isDark ? .white : T.ink
            )
            .tint(T.accent)
            .multilineTextAlignment(textAlignment)
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($searchFieldFocused)
            .onSubmit {
                searchFieldFocused = false
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .layoutPriority(1)
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(spacing: 12) {

            ZStack {

                Circle()
                    .fill(T.accentSoft)
                    .frame(width: 58, height: 58)

                Image(systemName: "square.grid.2x2")
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold
                        )
                    )
                    .foregroundColor(T.accent)
            }

            Text(
                languageCode == AppLanguage.arabic.rawValue
                    ? "لا توجد تطبيقات بعد"
                    : "No apps yet"
            )
            .font(T.sans(17, .bold))
            .foregroundColor(T.ink)

            Text(
                languageCode == AppLanguage.arabic.rawValue
                    ? "أضف مصدراً من تبويب التوقيع لاكتشاف التطبيقات هنا."
                    : "Add a source from the Sign tab to discover apps here."
            )
            .font(T.sans(12, .medium))
            .foregroundColor(T.ink3)
            .multilineTextAlignment(.center)
        }

        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, T.pad)

        .background {

            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(
                T.isDark
                    ? T.surface
                    : Color.white.opacity(0.90)
            )
        }

        .overlay {

            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                T.accent.opacity(0.20),
                lineWidth: 1
            )
        }

        .shadow(
            color: T.accent.opacity(0.07),
            radius: 16,
            x: 0,
            y: 7
        )

        .padding(.horizontal, T.pad)
        .padding(.top, 24)
    }

    // MARK: - App Card

    private func appRow(
        _ app: RepoApp
    ) -> some View {

        HStack(spacing: 13) {

            Button {

                selectedApp = app

            } label: {

                HStack(spacing: 13) {

                    CachedAppIcon(
                        url: app.iconURL,
                        size: 48,
                        cornerRadius: 13
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {

                        Text(app.name)
                            .font(
                                T.sans(
                                    16,
                                    .semibold
                                )
                            )
                            .foregroundColor(T.ink)
                            .lineLimit(1)

                        if let developer =
                            app.developerName,
                           !developer.isEmpty {

                            Text(developer)
                                .font(
                                    T.sans(
                                        11,
                                        .medium
                                    )
                                )
                                .foregroundColor(T.ink3)
                                .lineLimit(1)
                        }
                    }

                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }
                .contentShape(Rectangle())
            }

            .buttonStyle(.plain)

            getButton(app)
        }

        .padding(.horizontal, 14)
        .padding(.vertical, 13)

        .frame(maxWidth: .infinity)

        .background {

            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                T.isDark
                    ? T.surface
                    : Color.white.opacity(0.96)
            )
        }

        .overlay {

            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                T.accent.opacity(0.14),
                lineWidth: 1
            )
        }

        .shadow(
            color: T.accent.opacity(
                T.isDark ? 0.10 : 0.055
            ),
            radius: 14,
            x: 0,
            y: 6
        )
    }

    // MARK: - Install

    private func getButton(
        _ app: RepoApp
    ) -> some View {

        let isLoading =
            repositories.activeInstallID == app.id

        return GlassGetButton(

            isLoading: isLoading,

            isInstalled: false,

            disabled:
                app.downloadURL == nil ||
                (
                    repositories.activeInstallID != nil &&
                    repositories.activeInstallID != app.id
                )

        ) {

            if repositories.activeInstallID == app.id {

                repositories.cancelInstallAttempt(app.id)

            } else {

                repositories.clearInstalled(app.id)

                Task {
                    await repositories.download(app)
                }
            }
        }
    }
}
