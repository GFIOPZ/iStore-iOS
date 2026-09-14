import SwiftUI
import UIKit
import AudioToolbox

private enum TabIconImage {
    static func make(symbol: String, selected: Bool) -> UIImage {
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            guard let image = UIImage(systemName: symbol) else {
                return
            }

            let iconSize: CGFloat = selected ? 22 : 21

            let rect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )

            image
                .withTintColor(
                    selected ? .systemPurple : .label,
                    renderingMode: .alwaysOriginal
                )
                .draw(in: rect)
        }
        .withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - Application Delegate

final class ForgeApplicationDelegate: NSObject, UIApplicationDelegate {

    private var pendingShortcutURL: URL?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        if let shortcut =
            launchOptions?[.shortcutItem]
            as? UIApplicationShortcutItem {

            pendingShortcutURL = socialURL(
                for: shortcut.type
            )
        }

        configureQuickActions(application)

        CleanupManager.shared.performLaunchCleanup()

        return true
    }

    private func configureQuickActions(
        _ application: UIApplication
    ) {

        let telegram = UIApplicationShortcutItem(
            type: "com.hggdet.istore.telegram",
            localizedTitle: "Telegram",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(
                templateImageName: "QuickActionTelegram"
            ),
            userInfo: nil
        )

        let tiktok = UIApplicationShortcutItem(
            type: "com.hggdet.istore.tiktok",
            localizedTitle: "TikTok",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(
                templateImageName: "QuickActionTikTok"
            ),
            userInfo: nil
        )

        application.shortcutItems = [
            telegram,
            tiktok
        ]
    }

    func applicationDidBecomeActive(
        _ application: UIApplication
    ) {

        CleanupManager.shared.performResumeCleanup()

        CleanupManager.shared
            .checkPendingIPADeletionOnActivation()

        guard let url = pendingShortcutURL else {
            return
        }

        pendingShortcutURL = nil

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.45
        ) {
            application.open(
                url,
                options: [:]
            )
        }
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem:
            UIApplicationShortcutItem,
        completionHandler:
            @escaping (Bool) -> Void
    ) {

        guard let url = socialURL(
            for: shortcutItem.type
        ) else {

            completionHandler(false)
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.25
        ) {

            application.open(
                url,
                options: [:]
            ) { success in

                completionHandler(success)
            }
        }
    }

    private func socialURL(
        for type: String
    ) -> URL? {

        switch type {

        case "com.hggdet.istore.telegram":

            return URL(
                string: "https://t.me/ipafilesfor"
            )

        case "com.hggdet.istore.tiktok":

            return URL(
                string: "https://www.tiktok.com/@087.n"
            )

        default:

            return nil
        }
    }
}

// MARK: - App

@main
struct ForgeSignMobileApp: App {

    @UIApplicationDelegateAdaptor(
        ForgeApplicationDelegate.self
    )
    private var appDelegate

    @AppStorage("app.language")
    private var languageCode =
        AppLanguage.arabic.rawValue

    @StateObject
    private var certificates =
        CertificateStore()

    @StateObject
    private var profiles =
        ProfileStore()

    @StateObject
    private var history =
        HistoryStore()

    @StateObject
    private var installer =
        InstallController()

    @StateObject
    private var repositories =
        RepositoryStore()

    // MARK: NOVA VIP Authentication

    @StateObject
    private var auth =
        NOVAAuthService.shared

    init() {

        let defaults =
            UserDefaults.standard

        if defaults.object(
            forKey: "app.language.userSelected"
        ) == nil {

            defaults.set(
                AppLanguage.arabic.rawValue,
                forKey: "app.language"
            )
        }

        UITabBar.appearance().isHidden = true
    }

    var body: some Scene {

        let language =
            AppLanguage(
                rawValue: languageCode
            )
            ?? .english

        WindowGroup {

            ForgeRootView()

                .environment(
                    \.appLanguage,
                    language
                )

                .environment(
                    \.locale,
                    language.locale
                )

                .environment(
                    \.layoutDirection,
                    language.layoutDirection
                )

                .environmentObject(
                    certificates
                )

                .environmentObject(
                    profiles
                )

                .environmentObject(
                    history
                )

                .environmentObject(
                    installer
                )

                .environmentObject(
                    repositories
                )

                .environmentObject(
                    auth
                )
        }
    }
}

// MARK: - Root

@MainActor
private struct ForgeRootView: View {

    @Environment(
        \.colorScheme
    )
    private var colorScheme

    @Environment(
        \.scenePhase
    )
    private var scenePhase

    @EnvironmentObject
    private var auth:
        NOVAAuthService

    // شهادات وبروفايلات المستخدم
    @EnvironmentObject
    private var certificates:
        CertificateStore

    @EnvironmentObject
    private var profiles:
        ProfileStore

    @State
    private var tab = 0

    private var theme:
        ForgeTheme {

        colorScheme == .dark
            ? .dark
            : .light
    }

    var body:
        some View {

        Group {

            if auth.isLoggedIn {

                storeInterface

            } else {

                NOVAVIPLoginView()
            }
        }

        .forgeTheme(theme)

        .forgeScaledType()

        // MARK: Initial Authentication + Certificate Sync

        .task {

            await auth.validateSession()

            guard auth.isLoggedIn else {
                return
            }

            await NOVACertificateSyncService.shared.sync(
                auth: auth,
                certificates: certificates,
                profiles: profiles
            )
        }

        // MARK: Resume Authentication + Certificate Sync

        .onChange(
            of: scenePhase
        ) { newPhase in

            guard newPhase == .active else {
                return
            }

            guard auth.isLoggedIn else {
                return
            }

            Task { @MainActor in

                await auth.validateSession()

                guard auth.isLoggedIn else {
                    return
                }

                await NOVACertificateSyncService.shared.sync(
                    auth: auth,
                    certificates: certificates,
                    profiles: profiles
                )
            }
        }
    }

    // MARK: - Store

    private var storeInterface:
        some View {

        ZStack(
            alignment: .bottom
        ) {

            TabView(
                selection: $tab
            ) {

                NOVAHomeView()
                    .tag(0)

                NOVAAppsView()
                    .tag(1)

                ContentView()
                    .tag(2)

                AboutView()
                    .tag(3)
            }

            CustomFloatingTabBar(
                selectedTab: $tab,
                theme: theme
            )
        }

        .ignoresSafeArea(
            .keyboard,
            edges: .bottom
        )
    }
}

// MARK: - Floating Liquid Glass Tab Bar

private struct CustomFloatingTabBar: View {
    @Binding var selectedTab: Int
    let theme: ForgeTheme

    var body: some View {
        HStack(spacing: 4) {
            TabBarButton(id: 0, title: "الرئيسية", icon: "house.fill", selectedTab: $selectedTab, theme: theme)
            TabBarButton(id: 1, title: "التطبيقات", icon: "square.grid.2x2.fill", selectedTab: $selectedTab, theme: theme)
            TabBarButton(id: 2, title: "التوقيع", icon: "signature", selectedTab: $selectedTab, theme: theme)
            TabBarButton(id: 3, title: "الإعدادات", icon: "gearshape.fill", selectedTab: $selectedTab, theme: theme)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(height: 72)
        .glassSurface(.tabBar, cornerRadius: 27)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}

private struct TabBarButton: View {
    let id: Int
    let title: String
    let icon: String
    @Binding var selectedTab: Int
    let theme: ForgeTheme
    @State private var pressed = false

    private var isSelected: Bool { selectedTab == id }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                selectedTab = id
            }

            withAnimation(.easeOut(duration: 0.10)) {
                pressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
                    pressed = false
                }
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.accent.opacity(0.22),
                                        theme.accent.opacity(0.07)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(theme.accent.opacity(0.18), lineWidth: 0.8)
                            }
                            .frame(width: 50, height: 39)
                            .transition(.scale(scale: 0.82).combined(with: .opacity))
                    }

                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 18 : 17, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? theme.accent : theme.ink3)
                        .scaleEffect(pressed ? 0.88 : 1)
                }
                .frame(height: 39)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? theme.accent : theme.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
