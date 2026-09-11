import SwiftUI

struct NOVAHomeView: View {
    @Environment(\.forgeTheme) private var T
    @EnvironmentObject private var repositories: RepositoryStore
    @StateObject private var store = NOVAStoreService.shared
    @State private var selectedApp: NOVAApp?
    @State private var selectedBanner: NOVABanner?

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app.language") ?? AppLanguage.arabic.rawValue) ?? .arabic
    }

    private var latestApps: [NOVAApp] {
        Array(
            store.apps
                .sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
                .prefix(store.settings?.latestAppsLimit ?? 10)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    telegramCard

                    if !store.banners.isEmpty {
                        bannerCarousel
                    }

                    latestSection

                    if let error = store.errorMessage {
                        errorCard(error)
                    }
                }
                .padding(.horizontal, T.pad)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(ForgeBackdrop())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await store.refresh(force: true)
            }
            .task {
                await store.refresh()
                await syncExternalSources()
            }
            .sheet(item: $selectedApp) { app in
                NOVAAppDetailView(app: app)
                    .environmentObject(repositories)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("NOVA STORE")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [T.accentHi, T.accent, T.accentDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(language == .arabic ? "متجر التطبيقات والألعاب" : "Apps & Games Store")
                .font(T.sans(13, .semibold))
                .foregroundStyle(T.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var telegramCard: some View {
        let channel = store.settings?.supportChannel ?? "https://t.me/ipafilesfor"

        return Button {
            guard let url = URL(string: channel) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(T.accent, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(language == .arabic ? "تابعونا على قناة التحديثات" : "Follow our updates channel")
                        .font(T.sans(15, .bold))
                        .foregroundStyle(T.ink)

                    Text(language == .arabic ? "آخر الأخبار والتحديثات" : "News and updates")
                        .font(T.sans(11, .medium))
                        .foregroundStyle(T.ink3)
                }

                Spacer()
                Image(systemName: "chevron.left")
                    .foregroundStyle(T.accent)
            }
            .padding(14)
            .background(T.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(T.accent.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var bannerCarousel: some View {
        TabView(selection: $selectedBanner) {
            ForEach(store.banners) { banner in
                bannerCard(banner)
                    .tag(Optional(banner))
            }
        }
        .frame(height: 215)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }

    private func bannerCard(_ banner: NOVABanner) -> some View {
        Button {
            if let app = store.app(id: banner.appID) {
                selectedApp = app
            } else if let raw = banner.externalURL, let url = URL(string: raw) {
                UIApplication.shared.open(url)
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: banner.image) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(T.accent.opacity(0.15))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(banner.title)
                        .font(T.sans(20, .bold))
                        .foregroundStyle(.white)

                    if let description = banner.description, !description.isEmpty {
                        Text(description)
                            .font(T.sans(11, .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                    }

                    if let button = banner.buttonTitle, !button.isEmpty {
                        Text(button)
                            .font(T.sans(11, .bold))
                            .foregroundStyle(T.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white, in: Capsule())
                            .padding(.top, 3)
                    }
                }
                .padding(15)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var latestSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(language == .arabic ? "آخر التحديثات" : "Latest Updates")
                    .font(T.sans(20, .bold))
                    .foregroundStyle(T.ink)
                Spacer()
                Text("\(latestApps.count)")
                    .font(T.mono(11, .bold))
                    .foregroundStyle(T.accent)
            }

            if latestApps.isEmpty {
                Text(language == .arabic ? "لا توجد تطبيقات حالياً." : "No apps yet.")
                    .font(T.sans(13, .medium))
                    .foregroundStyle(T.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(30)
                    .background(T.surface, in: RoundedRectangle(cornerRadius: 18))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(latestApps) { app in
                        Button {
                            selectedApp = app
                        } label: {
                            appRow(app)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func appRow(_ app: NOVAApp) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: app.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(T.accent)
                }
            }
            .frame(width: 52, height: 52)
            .background(T.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(T.sans(15, .bold))
                    .foregroundStyle(T.ink)
                    .lineLimit(1)

                if let subtitle = app.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(T.sans(11, .medium))
                        .foregroundStyle(T.ink3)
                        .lineLimit(1)
                }

                if let version = app.version {
                    Text("v\(version)")
                        .font(T.mono(10))
                        .foregroundStyle(T.ink4)
                }
            }

            Spacer()
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(T.ink4)
        }
        .padding(12)
        .background(T.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(T.accent.opacity(0.12), lineWidth: 1)
        }
    }

    private func errorCard(_ error: String) -> some View {
        Text(error)
            .font(T.mono(10))
            .foregroundStyle(T.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(T.bad.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func syncExternalSources() async {
        for source in store.sources {
            guard source.type != "official",
                  let url = URL(string: source.repoURL),
                  !source.repoURL.isEmpty else { continue }

            if !repositories.repositories.contains(where: { $0.url == url }) {
                _ = repositories.add(urlString: source.repoURL)
            }
        }
    }
}