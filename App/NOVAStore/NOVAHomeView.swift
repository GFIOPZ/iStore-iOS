import SwiftUI
import UIKit

struct NOVAHomeView: View {
    
    @StateObject private var store = NOVAStoreService.shared
    @EnvironmentObject private var repositories: RepositoryStore
    
    @State private var selectedBanner: NOVABanner?
    @State private var selectedApp: NOVAApp?
    
    private var latestApps: [NOVAApp] {
        let limit = store.settings?.latestAppsLimit ?? 10
        return Array(store.apps.prefix(max(0, limit)))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if store.isLoading && store.apps.isEmpty {
                    ProgressView("جاري تحميل NOVA STORE...")
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            header
                            
                            updatesChannelCard
                            
                            if !store.banners.isEmpty {
                                bannersSection
                            }
                            
                            latestAppsSection
                            
                            sourcesSection
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        await store.refresh(force: true)
                        syncSources()
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await store.refresh()
                syncSources()
            }
            .sheet(item: $selectedBanner) { banner in
                bannerDestination(banner)
            }
            .sheet(item: $selectedApp) { app in
                NOVAAppDetailView(app: app)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.settings?.name ?? "NOVA STORE")
                    .font(.system(size: 30, weight: .bold))
                
                Text("متجرك للتطبيقات والألعاب")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                Task {
                    await store.refresh(force: true)
                    syncSources()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Telegram
    
    private var updatesChannelCard: some View {
        Button {
            openSupportChannel()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("تابعونا على قناة التحديثات")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("آخر الأخبار والتحديثات والعروض")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Banners
    
    private var bannersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("مميز")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)
            
            TabView(selection: $selectedBanner) {
                ForEach(store.banners) { banner in
                    BannerCard(banner: banner) {
                        selectedBanner = banner
                    }
                    .tag(Optional(banner))
                    .padding(.horizontal, 16)
                }
            }
            .frame(height: 210)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            
            if latestApps.isEmpty {
                emptyAppsView
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
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var emptyAppsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("لا توجد تطبيقات حالياً")
                .font(.headline)
            
            Text("ستظهر التطبيقات هنا عند إضافتها من لوحة التحكم.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    @ViewBuilder
    private func appRow(_ app: NOVAApp) -> some View {
        HStack(spacing: 13) {
            AsyncImage(url: URL(string: app.icon)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                    
                default:
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.secondary.opacity(0.12))
                        
                        Image(systemName: "app.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(app.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 7) {
                    if !app.version.isEmpty {
                        Text("v\(app.version)")
                    }
                    
                    if !app.size.isEmpty {
                        Text("•")
                        Text(app.size)
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(13)
        .background(
            RoundedRectangle(
                cornerRadius: 19,
                style: .continuous
            )
            .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Sources
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("المصادر")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)
            
            if store.sources.isEmpty {
                Text("لا توجد مصادر مفعلة")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.sources) { source in
                            sourceCard(source)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func sourceCard(_ source: NOVASource) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
            
            Text(source.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Banner Destination
    
    @ViewBuilder
    private func bannerDestination(_ banner: NOVABanner) -> some View {
        if let app = store.app(id: banner.appID) {
            NOVAAppDetailView(app: app)
        } else if !banner.externalURL.isEmpty {
            BannerExternalDestination(
                urlString: banner.externalURL
            )
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
    
    // MARK: - Sources Sync
    
    private func syncSources() {
        for source in store.sources {
            let repoURL = source.repoURL.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            
            guard !repoURL.isEmpty else {
                continue
            }
            
            guard let url = URL(string: repoURL) else {
                continue
            }
            
            guard !repositories.repositories.contains(where: {
                $0.url == url
            }) else {
                continue
            }
            
            _ = repositories.add(urlString: repoURL)
        }
    }
    
    // MARK: - Support
    
    private func openSupportChannel() {
        guard let value = store.settings?.supportChannel,
              !value.isEmpty,
              let url = URL(string: value) else {
            return
        }
        
        UIApplication.shared.open(url)
    }
}

// MARK: - Banner Card

private struct BannerCard: View {
    let banner: NOVABanner
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: banner.imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                        
                    default:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .purple.opacity(0.8),
                                        .blue.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipped()
                
                LinearGradient(
                    colors: [
                        .black.opacity(0.8),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(banner.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    if !banner.subtitle.isEmpty {
                        Text(banner.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    
                    if !banner.buttonTitle.isEmpty {
                        Text(banner.buttonTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(18)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
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
                
                if let url = URL(string: urlString),
                   !urlString.isEmpty {
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

#Preview {
    NOVAHomeView()
        .environmentObject(RepositoryStore())
}
