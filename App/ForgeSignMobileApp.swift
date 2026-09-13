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

            pendingShortcutURL =
                socialURL(
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

        let telegram =
            UIApplicationShortcutItem(
                type:
                    "com.hggdet.istore.telegram",
                localizedTitle:
                    "Telegram",
                localizedSubtitle:
                    nil,
                icon:
                    UIApplicationShortcutIcon(
                        templateImageName:
                            "QuickActionTelegram"
                    ),
                userInfo:
                    nil
            )


        let tiktok =
            UIApplicationShortcutItem(
                type:
                    "com.hggdet.istore.tiktok",
                localizedTitle:
                    "TikTok",
                localizedSubtitle:
                    nil,
                icon:
                    UIApplicationShortcutIcon(
                        templateImageName:
                            "QuickActionTikTok"
                    ),
                userInfo:
                    nil
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


        guard
            let url = pendingShortcutURL
        else {
            return
        }

        pendingShortcutURL = nil


        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.45
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

        guard
            let url =
                socialURL(
                    for: shortcutItem.type
                )
        else {

            completionHandler(false)

            return
        }


        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.25
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
                string:
                    "https://t.me/ipafilesfor"
            )


        case "com.hggdet.istore.tiktok":

            return URL(
                string:
                    "https://www.tiktok.com/@087.n"
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


    // ⭐ نظام NOVA VIP الجديد
    @StateObject
    private var auth =
        NOVAAuthService.shared


    init() {

        let defaults =
            UserDefaults.standard


        if defaults.object(
            forKey:
                "app.language.userSelected"
        ) == nil {

            defaults.set(
                AppLanguage.arabic.rawValue,
                forKey:
                    "app.language"
            )
        }


        UITabBar.appearance().isHidden = true
    }


    var body: some Scene {

        let language =
            AppLanguage(
                rawValue:
                    languageCode
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

                // ⭐ مهم جداً
                .environmentObject(
                    auth
                )
        }
    }
}


// MARK: - VIP State

private enum VIPValidationState {

    case validating
    case authorized
}


// MARK: - Root

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


    @State
    private var tab = 0


    @State
    private var validationState:
        VIPValidationState = .validating


    private var theme:
        ForgeTheme {

        colorScheme == .dark
            ? .dark
            : .light
    }


    var body: some View {

        Group {

            if auth.isLoggedIn {

                if validationState ==
                    .validating {

                    NOVAVIPValidationView {

                        withAnimation(
                            .easeOut(
                                duration:
                                    0.3
                            )
                        ) {

                            validationState =
                                .authorized
                        }

                    } onFail: {

                        withAnimation(
                            .easeIn
                        ) {

                            auth.logout()

                            validationState =
                                .validating
                        }
                    }

                } else {

                    storeInterface
                }

            } else {

                NOVAVIPLoginView()
            }
        }

        .forgeTheme(theme)

        .forgeScaledType()

        .task {

            guard auth.isLoggedIn else {
                return
            }

            await auth.validateSession()

            if auth.isLoggedIn {

                validationState =
                    .authorized

            } else {

                validationState =
                    .validating
            }
        }

        .onChange(
            of: scenePhase
        ) { newPhase in

            guard
                newPhase == .active
            else {
                return
            }


            if auth.isLoggedIn {

                validationState =
                    .validating

                Task {

                    await auth.validateSession()

                    if auth.isLoggedIn {

                        await MainActor.run {

                            validationState =
                                .authorized
                        }
                    }
                }
            }
        }

        .onChange(
            of: auth.isLoggedIn
        ) { loggedIn in

            if loggedIn {

                validationState =
                    .validating

            } else {

                validationState =
                    .validating
            }
        }
    }


    // MARK: Store

    private var storeInterface:
        some View {

        ZStack(
            alignment:
                .bottom
        ) {

            TabView(
                selection:
                    $tab
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
                selectedTab:
                    $tab,
                theme:
                    theme
            )
        }

        .ignoresSafeArea(
            .keyboard,
            edges:
                .bottom
        )
    }
}


// MARK: - Floating Tab Bar

private struct CustomFloatingTabBar:
    View {

    @Binding
    var selectedTab:
        Int


    let theme:
        ForgeTheme


    var body:
        some View {

        HStack(
            spacing: 0
        ) {

            TabBarButton(
                id: 0,
                title:
                    "الرئيسية",
                icon:
                    "house.fill",
                selectedTab:
                    $selectedTab,
                theme:
                    theme
            )


            TabBarButton(
                id: 1,
                title:
                    "التطبيقات",
                icon:
                    "square.grid.2x2.fill",
                selectedTab:
                    $selectedTab,
                theme:
                    theme
            )


            TabBarButton(
                id: 2,
                title:
                    "التوقيع",
                icon:
                    "signature",
                selectedTab:
                    $selectedTab,
                theme:
                    theme
            )


            TabBarButton(
                id: 3,
                title:
                    "الإعدادات",
                icon:
                    "gearshape.fill",
                selectedTab:
                    $selectedTab,
                theme:
                    theme
            )
        }

        .padding(
            .horizontal,
            10
        )

        .padding(
            .top,
            10
        )

        .padding(
            .bottom,
            24
        )

        .background(

            LinearGradient(
                colors: [
                    .clear,
                    Color(
                        .systemBackground
                    )
                    .opacity(0.4),

                    Color(
                        .systemBackground
                    )
                    .opacity(0.9)
                ],

                startPoint:
                    .top,

                endPoint:
                    .bottom
            )

            .ignoresSafeArea()

            .allowsHitTesting(
                false
            )
        )
    }
}


// MARK: - Tab Button

private struct TabBarButton:
    View {

    let id:
        Int

    let title:
        String

    let icon:
        String


    @Binding
    var selectedTab:
        Int


    let theme:
        ForgeTheme


    @State
    private var isAnimating =
        false


    private var isSelected:
        Bool {

        selectedTab == id
    }


    var body:
        some View {

        Button {

            UIImpactFeedbackGenerator(
                style:
                    .light
            )
            .impactOccurred()


            selectedTab =
                id


            triggerAnimation()

        } label: {

            VStack(
                spacing:
                    5
            ) {

                ZStack {

                    Circle()

                        .fill(
                            isSelected
                                ? theme.accent
                                    .opacity(
                                        0.15
                                    )
                                : .clear
                        )

                        .frame(
                            width:
                                48,
                            height:
                                48
                        )


                    Image(
                        systemName:
                            icon
                    )

                    .font(
                        .system(
                            size:
                                20,
                            weight:
                                .semibold
                        )
                    )

                    .foregroundColor(
                        isSelected
                            ? theme.accent
                            : Color.gray
                                .opacity(
                                    0.6
                                )
                    )

                    .offset(
                        y:
                            isAnimating
                                ? -12
                                : 0
                    )

                    .rotationEffect(
                        .degrees(
                            isAnimating
                                ? 15
                                : 0
                        )
                    )
                }


                Text(title)

                    .font(
                        .system(
                            size:
                                11,
                            weight:
                                isSelected
                                    ? .bold
                                    : .medium
                        )
                    )

                    .foregroundColor(
                        isSelected
                            ? theme.accent
                            : Color.gray
                                .opacity(
                                    0.6
                                )
                    )
            }

            .frame(
                maxWidth:
                    .infinity
            )

            .contentShape(
                Rectangle()
            )
        }

        .buttonStyle(
            .plain
        )
    }


    private func triggerAnimation() {

        withAnimation(
            .spring(
                response:
                    0.3,
                dampingFraction:
                    0.5,
                blendDuration:
                    0.5
            )
        ) {

            isAnimating =
                true
        }


        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.2
        ) {

            withAnimation(
                .spring(
                    response:
                        0.3,
                    dampingFraction:
                        0.5,
                    blendDuration:
                        0.5
                )
            ) {

                isAnimating =
                    false
            }
        }
    }
}
