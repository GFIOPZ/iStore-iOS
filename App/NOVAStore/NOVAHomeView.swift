import SwiftUI
import UIKit

struct NOVAHomeView: View {
    
    @StateObject private var store = NOVAStoreService.shared
    @EnvironmentObject private var repositories: RepositoryStore
    
    @State private var selectedBanner: NOVABanner?
    @State private var selectedApp: RepoApp?
    @State private var didInitialRefresh = false // تمنع التحميل المتكرر عند التنقل
    
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
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            header
                            
                            updatesChannelCard
                            
                            if !store.banners.isEmpty {
                                bannersSection
                            }
                            
                            latestAppsSection
                            
                            // تم حذف قسم المصادر من هنا نهائياً
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable {
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
            .sheet(item: $selectedBanner) { banner in
                bannerDestination(banner)
            }
            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }
        }
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
                
                Text("متجرك للتطبيقات والألعاب")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                Task {
                    await store.refresh(force: true)
                    await refreshRepositoryCatalogs()
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
            TabView(selection: $selectedBanner) {
                ForEach(store.banners) { banner in
                    BannerCard(banner: banner) {
                        selectedBanner = banner
                    }
                    .tag(Optional(banner))
                    .padding(.horizontal, 16)
                }
            }
            // زيادة الارتفاع ليتناسب مع التصميم الاحترافي الجديد للبنر
            .frame(height: 320)
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
        HStack(spacing: 13) {
            CachedAppIcon(url: app.iconURL, size: 58, cornerRadius: 15)

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
    
    // MARK: - Banner Destination
    
    @ViewBuilder
    private func bannerDestination(_ banner: NOVABanner) -> some View {
        if let appID = banner.appID, let app = store.app(id: appID) {
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

// MARK: - Banner Card (التصميم الجديد المطابق للصورة)

private struct BannerCard: View {
    let banner: NOVABanner
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // القسم العلوي: صورة البنر
                AsyncImage(url: URL(string: banner.imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(height: 200)
                .clipped()
                
                // القسم السفلي: الخلفية الكحلية الأنيقة مع النصوص والزر
                HStack(alignment: .center, spacing: 12) {
                    
                    // الزر على اليسار
                    if !banner.buttonTitle.isEmpty {
                        Text(banner.buttonTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // النصوص على اليمين
                    VStack(alignment: .trailing, spacing: 3) {
                        if !banner.subtitle.isEmpty {
                            Text(banner.subtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        Text(banner.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                        
                        if !banner.description.isEmpty {
                            Text(banner.description)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                // اللون الكحلي المطابق للصورة
                .background(Color(red: 0.17, green: 0.24, blue: 0.35))
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
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
