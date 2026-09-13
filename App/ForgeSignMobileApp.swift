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
                .environmentObject(certificates)
                .environmentObject(profiles)
                .environmentObject(history)
                .environmentObject(installer)
                .environmentObject(repositories)
        }
    }
}

// حالة التحقق
enum VIPValidationState {
    case validating
    case authorized
}

private struct ForgeRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State private var tab = 0
    
    @AppStorage("isVIPLoggedIn") private var isVIPLoggedIn = false
    @State private var validationState: VIPValidationState = .validating

    private var theme: ForgeTheme {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        Group {
            if isVIPLoggedIn {
                if validationState == .validating {
                    // شاشة التحقق الفخمة عند كل عملية فتح للتطبيق
                    NOVAVIPValidationView {
                        // نجاح التحقق -> ادخل للمتجر
                        withAnimation(.easeOut(duration: 0.3)) {
                            validationState = .authorized
                        }
                    } onFail: {
                        // فشل التحقق -> اطرد المستخدم لواجهة تسجيل الدخول
                        withAnimation(.easeIn) {
                            isVIPLoggedIn = false
                            validationState = .validating // تصفير الحالة للمرات القادمة
                        }
                    }
                } else {
                    // واجهة المتجر الرئيسية
                    TabView(selection: $tab) {
                        NOVAHomeView()
                            .tabItem { Label("الرئيسية", systemImage: tab == 0 ? "house.fill" : "house") }
                            .tag(0)

                        NOVAAppsView()
                            .tabItem { Label("التطبيقات", systemImage: tab == 1 ? "square.grid.2x2.fill" : "square.grid.2x2") }
                            .tag(1)

                        ContentView()
                            .tabItem { Label("التوقيع", systemImage: tab == 2 ? "signature" : "signature") }
                            .tag(2)

                        AboutView()
                            .tabItem { Label("الإعدادات", systemImage: tab == 3 ? "gearshape.fill" : "gearshape") }
                            .tag(3)
                    }
                    .tint(theme.accent)
                }
            } else {
                NOVAVIPLoginView()
            }
        }
        .forgeTheme(theme)
        .forgeScaledType()
        .onChange(of: scenePhase) { newPhase in
            // إجبار التطبيق على شاشة التحقق في كل مرة يعود فيها للواجهة
            if newPhase == .active && isVIPLoggedIn {
                validationState = .validating
            }
        }
    }
}

// MARK: - شاشة التحقق من الترخيص (VIP Validation Screen)
struct NOVAVIPValidationView: View {
    @AppStorage("vip_username") private var vipUsername = ""
    @AppStorage("vip_password") private var vipPassword = ""
    @AppStorage("vip_code") private var vipCode = ""
    
    var onSuccess: () -> Void
    var onFail: () -> Void
    
    @State private var isPulsing = false
    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(gradientStart.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color(hex: "FFD700").opacity(0.4), radius: 10, x: 0, y: 5)
                }
                
                VStack(spacing: 8) {
                    Text("NOVA VIP")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [gradientStart, gradientEnd],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    
                    Text("جاري التحقق من الترخيص...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: gradientStart))
                    .scaleEffect(1.2)
                    .padding(.top, 10)
            }
        }
        .onAppear {
            isPulsing = true
            Task { await performCheck() }
        }
    }
    
    private func performCheck() async {
        // تأخير بسيط لإعطاء فخامة للشاشة وتجنب الوميض السريع
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        guard !vipUsername.isEmpty, let url = URL(string: "https://nova-ipa.hassanyipa.workers.dev/") else {
            await MainActor.run { onFail() }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SuperNova2026!", forHTTPHeaderField: "Nova-Secret")
        request.cachePolicy = .reloadIgnoringLocalCacheData // منع استخدام الكاش القديم
        
        let bodyData: [String: String] = [
            "username": vipUsername,
            "password": vipPassword,
            "code": vipCode
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { onFail() }
                return
            }
            
            if httpResponse.statusCode == 200 {
                // نجاح التحقق
                await MainActor.run { onSuccess() }
            } else {
                // طرد (مرفوض، محظور، أو منتهي)
                await clearCredentialsAndFail()
            }
        } catch {
            // في حال عدم وجود إنترنت، ممكن نخليه يعبر أو يرفض، الأفضل نطرده كإجراء أمني صارم
            // أو نمرره مؤقتاً إذا ردنا تساهل. حالياً راح نرفض الدخول.
            await MainActor.run { onFail() }
        }
    }
    
    @MainActor
    private func clearCredentialsAndFail() {
        vipUsername = ""
        vipPassword = ""
        vipCode = ""
        onFail()
    }
}
