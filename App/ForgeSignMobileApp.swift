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
        }.withRenderingMode(.alwaysOriginal)
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

    // المحركات المسؤولة عن التوقيع وإدارة التطبيقات
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
            ForgeRootView()
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .environment(\.layoutDirection, language.layoutDirection)
                // تمرير المحركات لكل الواجهات حتى يعمل الاستيراد التلقائي للشهادات في الـ VIP
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
    
    // جلب حالة تسجيل الدخول لمعرفة إذا كان المستخدم VIP أو لا
    @AppStorage("isVIPLoggedIn") private var isVIPLoggedIn = false

    private var theme: ForgeTheme {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        Group {
            // الشرط الذكي: إذا المشترك مسجل دخول يروح للمتجر (التابات)، إذا لا تطلعله واجهة الدخول الفخمة
            if isVIPLoggedIn {
                TabView(selection: $tab) {
                    NOVAHomeView()
                        .tabItem {
                            Label("الرئيسية", systemImage: tab == 0 ? "house.fill" : "house")
                        }
                        .tag(0)

                    NOVAAppsView()
                        .tabItem {
                            Label("التطبيقات", systemImage: tab == 1 ? "square.grid.2x2.fill" : "square.grid.2x2")
                        }
                        .tag(1)

                    ContentView()
                        .tabItem {
                            Label("التوقيع", systemImage: tab == 2 ? "signature" : "signature")
                        }
                        .tag(2)

                    AboutView()
                        .tabItem {
                            Label("الإعدادات", systemImage: tab == 3 ? "gearshape.fill" : "gearshape")
                        }
                        .tag(3)
                }
                .tint(theme.accent)
            } else {
                // عرض واجهة تسجيل الدخول كأول شاشة
                NOVAVIPLoginView()
            }
        }
        .forgeTheme(theme)
        .forgeScaledType()
    }
}
