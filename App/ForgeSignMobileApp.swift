import SwiftUI
import UIKit

private enum TabIconImage {
    static func make(symbol: String, selected: Bool) -> UIImage {
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            guard let image = UIImage(systemName: symbol) else { return }

            let iconSize: CGFloat = selected ? 22 : 21
            let rect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )

            image.withTintColor(
                selected ? .systemPurple : .label,
                renderingMode: .alwaysOriginal
            ).draw(in: rect)
        }
        .withRenderingMode(.alwaysOriginal)
    }
}

final class ForgeApplicationDelegate: NSObject, UIApplicationDelegate {
    private var pendingShortcutURL: URL?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            pendingShortcutURL = socialURL(for: shortcut.type)
        }

        configureQuickActions(application)
        CleanupManager.shared.performLaunchCleanup()
        return true
    }

    private func configureQuickActions(_ application: UIApplication) {
        let telegram = UIApplicationShortcutItem(
            type: "com.hggdet.istore.telegram",
            localizedTitle: "Telegram",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(templateImageName: "QuickActionTelegram"),
            userInfo: nil
        )

        let tiktok = UIApplicationShortcutItem(
            type: "com.hggdet.istore.tiktok",
            localizedTitle: "TikTok",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(templateImageName: "QuickActionTikTok"),
            userInfo: nil
        )

        application.shortcutItems = [telegram, tiktok]
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        CleanupManager.shared.performResumeCleanup()
        CleanupManager.shared.checkPendingIPADeletionOnActivation()

        guard let url = pendingShortcutURL else { return }
        pendingShortcutURL = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            application.open(url, options: [:])
        }
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let url = socialURL(for: shortcutItem.type) else {
            completionHandler(false)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            application.open(url, options: [:]) { success in
                completionHandler(success)
            }
        }
    }

    private func socialURL(for type: String) -> URL? {
        switch type {
        case "com.hggdet.istore.telegram":
            return URL(string: "https://t.me/ipafilesfor")
        case "com.hggdet.istore.tiktok":
            return URL(string: "https://www.tiktok.com/@087.n")
        default:
            return nil
        }
    }
}

@main
struct ForgeSignMobileApp: App {
    @UIApplicationDelegateAdaptor(ForgeApplicationDelegate.self) private var appDelegate

    @AppStorage("app.language")
    private var languageCode = AppLanguage.arabic.rawValue

    @StateObject private var certificates = CertificateStore()
    @StateObject private var profiles = ProfileStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var installer = InstallController()
    @StateObject private var repositories = RepositoryStore()

    init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "app.language.userSelected") == nil {
            defaults.set(AppLanguage.arabic.rawValue, forKey: "app.language")
        }
    }

    var body: some Scene {
        let language = AppLanguage(rawValue: languageCode) ?? .english

        WindowGroup {
            NOVAStartupView {
                ForgeRootView()
            }
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .environment(\.layoutDirection, language.layoutDirection)
            .environmentObject(certificates)
            .environmentObject(profiles)
            .environmentObject(history)
            .environmentObject(installer)
            .environmentObject(repositories)
        }
    }
}

private struct ForgeRootView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var tab = 0

    private var theme: ForgeTheme {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        TabView(selection: $tab) {

            // 1 — الرئيسية
            ZedHomeView()
                .tabItem {
                    Label {
                        Text("الرئيسية")
                    } icon: {
                        Image(
                            uiImage: TabIconImage.make(
                                symbol: "house.fill",
                                selected: tab == 0
                            )
                        )
                    }
                }
                .tag(0)

            // 2 — التطبيقات
            AppsView()
                .tabItem {
                    Label {
                        Text("التطبيقات")
                    } icon: {
                        Image(
                            uiImage: TabIconImage.make(
                                symbol: "square.grid.2x2.fill",
                                selected: tab == 1
                            )
                        )
                    }
                }
                .tag(1)

            // 3 — التوقيع
            ContentView()
                .tabItem {
                    Label {
                        Text("التوقيع")
                    } icon: {
                        Image(
                            uiImage: TabIconImage.make(
                                symbol: "signature",
                                selected: tab == 2
                            )
                        )
                    }
                }
                .tag(2)

            // 4 — الإعدادات
            AboutView()
                .tabItem {
                    Label {
                        Text("الإعدادات")
                    } icon: {
                        Image(
                            uiImage: TabIconImage.make(
                                symbol: "gearshape.fill",
                                selected: tab == 3
                            )
                        )
                    }
                }
                .tag(3)
        }
        .tint(theme.accent)
        .forgeTheme(theme)
        .forgeScaledType()
    }
}
