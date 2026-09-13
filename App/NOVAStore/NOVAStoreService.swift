import Foundation
import Combine

@MainActor
final class NOVAStoreService: ObservableObject {

    static let shared = NOVAStoreService()

    // MARK: - Published Data

    @Published private(set) var apps: [NOVAApp] = []
    @Published private(set) var banners: [NOVABanner] = []
    @Published private(set) var categories: [NOVACategory] = []
    @Published private(set) var sources: [NOVASource] = []
    @Published private(set) var settings: NOVAStoreSettings?

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Private

    private let baseURL = URL(
        string: "https://nova-ipa.hassanyipa.workers.dev"
    )!

    private let decoder = JSONDecoder()

    private var loaded = false

    private init() {}

    // MARK: - Refresh

    func refresh(force: Bool = false) async {

        if loaded && !force {
            return
        }

        guard NOVAAuthService.shared.isLoggedIn else {
            errorMessage = "يجب تسجيل الدخول أولاً."
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            async let appsResponse:
                NOVAAppsResponse =
                    fetch("apps.json")

            async let bannersResponse:
                NOVABannersResponse =
                    fetch("banners.json")

            async let categoriesResponse:
                NOVACategoriesResponse =
                    fetch("categories.json")

            async let sourcesResponse:
                NOVASourcesResponse =
                    fetch("sources.json")

            async let settingsResponse:
                NOVASettingsResponse =
                    fetch("settings.json")

            let (
                appsValue,
                bannersValue,
                categoriesValue,
                sourcesValue,
                settingsValue
            ) = try await (
                appsResponse,
                bannersResponse,
                categoriesResponse,
                sourcesResponse,
                settingsResponse
            )

            // MARK: Apps

            apps =
                appsValue.apps
                    .filter {
                        $0.enabled
                    }

            // MARK: Banners

            banners =
                bannersValue.banners
                    .filter {
                        $0.enabled
                    }
                    .sorted {
                        $0.sortOrder < $1.sortOrder
                    }

            // MARK: Categories

            categories =
                categoriesValue.categories
                    .filter {
                        $0.enabled
                    }

            // MARK: Sources

            sources =
                sourcesValue.sources
                    .filter {
                        $0.enabled &&
                        $0.showInStore
                    }

            // MARK: Settings

            settings =
                settingsValue.store

            loaded = true

        } catch {

            errorMessage =
                error.localizedDescription

            print(
                """
                [NOVA STORE]
                Failed to load store data:
                \(error)
                """
            )
        }
    }

    // MARK: - Force Refresh

    func forceRefresh() async {
        await refresh(force: true)
    }

    // MARK: - Find App

    func app(
        id: String?
    ) -> NOVAApp? {

        guard let id else {
            return nil
        }

        return apps.first {
            $0.id == id
        }
    }

    // MARK: - Fetch

    private func fetch<T: Decodable>(
        _ filename: String
    ) async throws -> T {

        let cleanFilename =
            filename
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )

        guard
            let url = URL(
                string:
                    "\(baseURL.absoluteString)/v1/store/\(cleanFilename)"
            )
        else {
            throw URLError(.badURL)
        }

        // المصادقة أصبحت بواسطة Session Token
        // ولا يوجد أي Secret داخل التطبيق.
        let request =
            try await NOVAAuthService.shared
                .authorizedRequest(
                    path:
                        "/v1/store/\(cleanFilename)"
                )

        let (
            data,
            response
        ) =
            try await URLSession.shared.data(
                for: request
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {
            throw URLError(
                .badServerResponse
            )
        }

        switch httpResponse.statusCode {

        case 200...299:
            break

        case 401, 403:

            await NOVAAuthService.shared
                .validateSession()

            throw URLError(
                .userAuthenticationRequired
            )

        case 404:

            throw NSError(
                domain:
                    "NOVAStoreService",
                code:
                    404,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "ملف \(cleanFilename) غير موجود في مستودع NOVA-STORE."
                ]
            )

        default:

            throw NSError(
                domain:
                    "NOVAStoreService",
                code:
                    httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "تعذر تحميل \(cleanFilename). رمز الخادم: \(httpResponse.statusCode)"
                ]
            )
        }

        do {

            return try decoder.decode(
                T.self,
                from: data
            )

        } catch {

            print(
                """
                [NOVA STORE]
                JSON Decode Error:
                \(cleanFilename)

                \(error)
                """
            )

            throw error
        }
    }
}
