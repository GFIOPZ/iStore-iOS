import SwiftUI
/// Apps tab — a compact storefront for apps discovered from connected sources.
struct AppsView: View {
    @EnvironmentObject private var repositories: RepositoryStore
    @Environment(\.forgeTheme) private var T
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage("app.language") private var languageCode = AppLanguage.english.rawValue

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
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            displayedApps = allApps
            return
        }
        displayedApps = allApps.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            (app.developerName?.localizedCaseInsensitiveContains(query) ?? false) ||
            (app.localizedDescription?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            if displayedApps.isEmpty {
                                emptyState
                            } else {
                                ForEach(displayedApps.indices, id: \.self) { index in
                                    appRow(displayedApps[index])
                                        .padding(.horizontal, T.pad)
                                        .padding(.bottom, 12)
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
                                    .padding(.vertical, 8)
                            }
                            // تغيير لون خلفية الهيدر لتكون بيضاء بلمسة شفافة
                            .background(Color.white.opacity(T.isDark ? 0.05 : 0.94))
                            .zIndex(2)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .scrollContentBackground(.hidden)
                .background { ForgeBackdrop() }
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .top) {
                    // تدرج لوني خفيف من الأعلى للأسفل
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.15),
                            Color.white.opacity(0.8),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 92)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }
                .task {
                    guard !didInitialRefresh else { return }
                    while !repositories.catalogCacheLoaded {
                        try? await Task.sleep(nanoseconds: 20_000_000)
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
                        try await Task.sleep(nanoseconds: 120_000_000)
                    } catch {
                        return
                    }
                    guard !Task.isCancelled else { return }
                    refreshDisplayedApps()
                }
            }
            .contentShape(Rectangle())
            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }
            .alert(
                languageCode == AppLanguage.arabic.rawValue ? "تعذر تثبيت التطبيق" : "App Installation Failed",
                isPresented: Binding(
                    get: { repositories.downloadError != nil || repositories.installError != nil },
                    set: { isPresented in
                        if !isPresented {
                            repositories.downloadError = nil
                            repositories.installError = nil
                        }
                    }
                )
            ) {
                Button(languageCode == AppLanguage.arabic.rawValue ? "حسناً" : "OK", role: .cancel) {
                    repositories.downloadError = nil
                    repositories.installError = nil
                }
            } message: {
                Text(repositories.downloadError ?? repositories.installError ?? "")
            }
        }
    }

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

    // هنا قمنا بتعديل العنوان ليصبح "Zed Store" باللون البنفسجي
    private var titleHeader: some View {
        let isArabic = languageCode == AppLanguage.arabic.rawValue
        return Text("Zed Store")
            // استخدام خط Serif احترافي لاسم المتجر
            .font(.custom("Georgia-Bold", size: 36))
            // تغيير لون العنوان إلى البنفسجي
            .foregroundColor(Color(UIColor.systemPurple))
            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
            .padding(.horizontal, T.pad)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background {
                LinearGradient(
                    colors: [
                        Color.white.opacity(T.isDark ? 0.1 : 0.92),
                        Color.white.opacity(T.isDark ? 0.0 : 0.56),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blur(radius: 14)
                .padding(.horizontal, -22)
                .padding(.top, -12)
                .padding(.bottom, -8)
                .allowsHitTesting(false)
            }
            .environment(\.layoutDirection, .leftToRight)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            if languageCode == AppLanguage.arabic.rawValue {
                searchField
                searchIcon
            } else {
                searchIcon
                searchField
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 12)
        .frame(height: 40)
        // إعطاء خلفية بيضاء مع إطار بنفسجي خفيف لشريط البحث
        .background(Color.white.opacity(T.isDark ? 0.2 : 0.8))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(UIColor.systemPurple).opacity(0.3), lineWidth: 1)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: languageCode)
    }

    private var searchIcon: some View {
        Button {
            searchFieldFocused = false
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .bold))
                // لون أيقونة البحث بنفسجي
                .foregroundColor(Color(UIColor.systemPurple))
                .frame(width: 30, height: 30, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        let isArabic = languageCode == AppLanguage.arabic.rawValue
        let textAlignment: TextAlignment = isArabic ? .trailing : .leading
        let frameAlignment: Alignment = isArabic ? .trailing : .leading
        let placeholder = isArabic ? "ألعاب وتطبيقات والمزيد" : "Games, apps and more"

        return ZStack(alignment: frameAlignment) {
            if searchText.isEmpty {
                Text(placeholder)
                    .font(T.sans(15, .bold))
                    // لون النص الإرشادي بنفسجي فاتح
                    .foregroundColor(Color(UIColor.systemPurple).opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .allowsHitTesting(false)
            }

            TextField("", text: $searchText)
                .textFieldStyle(.plain)
                .font(T.sans(15, .bold))
                // لون النص عند الكتابة بنفسجي غامق
                .foregroundColor(T.isDark ? .white : Color(UIColor.systemPurple))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($searchFieldFocused)
                .onSubmit { searchFieldFocused = false }
        }
        .environment(\.layoutDirection, .leftToRight)
        .layoutPriority(1)
    }

    private var emptyState: some View {
        VStack(spacing: T.gap) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 20))
                .foregroundColor(Color(UIColor.systemPurple))
            Text(languageCode == AppLanguage.arabic.rawValue ? "لا توجد تطبيقات بعد" : "No apps yet")
                .font(T.sans(15, .medium))
                .foregroundColor(T.ink)
            MonoText(text: languageCode == AppLanguage.arabic.rawValue ? "أضف مصدراً من تبويب التوقيع لاكتشاف التطبيقات هنا." : "Add a source from the Sign tab to discover apps here.", size: 10, color: T.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, T.pad)
        .fGlass(cornerRadius: 16)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(UIColor.systemPurple).opacity(0.2), lineWidth: 1)
        }
        .padding(.horizontal, T.pad)
        .padding(.top, 24)
    }

    private func appRow(_ app: RepoApp) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedApp = app
            } label: {
                HStack(spacing: 12) {
                    CachedAppIcon(url: app.iconURL, size: 44, cornerRadius: 11)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(app.name)
                            .font(T.sans(15, .medium))
                            .foregroundColor(T.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            getButton(app)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        // بطاقة التطبيق بخلفية بيضاء نقية مع ظل خفيف (يمكنك تعديل glassSurface إذا كان مخصصاً)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func getButton(_ app: RepoApp) -> some View {
        let isLoading = repositories.activeInstallID == app.id
        return GlassGetButton(
            isLoading: isLoading,
            isInstalled: false,
            disabled: app.downloadURL == nil ||
                (repositories.activeInstallID != nil && repositories.activeInstallID != app.id)
        ) {
            if repositories.activeInstallID == app.id {
                repositories.cancelInstallAttempt(app.id)
            } else {
                repositories.clearInstalled(app.id)
                Task { await repositories.download(app) }
            }
        }
    }
}
