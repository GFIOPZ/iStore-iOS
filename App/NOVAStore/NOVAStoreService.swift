import Foundation
import Combine

@MainActor
final class NOVAStoreService: ObservableObject {

    // MARK: - Singleton

    static let shared = NOVAStoreService()

    // MARK: - Published Data

    @Published private(set) var apps: [NOVAApp] = []

    @Published private(set) var banners: [NOVABanner] = []

    @Published private(set) var categories: [NOVACategory] = []

    @Published private(set) var sources: [NOVASource] = []

    @Published private(set) var settings: NOVAStoreSettings?

    @Published private(set) var isLoading = false

    @Published private(set) var errorMessage: String?

    // MARK: - Configuration

    private let baseURL =
        URL(
            string:
                "https://nova-ipa.hassanyipa.workers.dev"
        )!

    private let decoder =
        JSONDecoder()

    private var loaded = false

    // MARK: - Init

    private init() {}

    // MARK: - Refresh

    func refresh(
        force: Bool = false
    ) async {

        // لا نعيد التحميل إذا البيانات موجودة
        guard
            !loaded || force
        else {
            return
        }

        // يجب أن يكون المستخدم مسجل دخول
        guard
            NOVAAuthService.shared.isLoggedIn
        else {

            errorMessage =
                "يجب تسجيل الدخول أولاً."

            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            async let appsResult:
                NOVAAppsResponse =
                    fetch(
                        "apps.json"
                    )

            async let bannersResult:
                NOVABannersResponse =
                    fetch(
                        "banners.json"
                    )

            async let categoriesResult:
                NOVACategoriesResponse =
                    fetch(
                        "categories.json"
                    )

            async let sourcesResult:
                NOVASourcesResponse =
                    fetch(
                        "sources.json"
                    )

            async let settingsResult:
                NOVASettingsResponse =
                    fetch(
                        "settings.json"
                    )

            let (
                appsValue,
                bannersValue,
                categoriesValue,
                sourcesValue,
                settingsValue
            ) = try await (
                appsResult,
                bannersResult,
                categoriesResult,
                sourcesResult,
                settingsResult
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
                        $0.sortOrder
                        <
                        $1.sortOrder
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

            print(
                """
                [NOVA STORE] Loaded successfully
                Apps: \(apps.count)
                Banners: \(banners.count)
                Categories: \(categories.count)
                Sources: \(sources.count)
                Settings: \(settings != nil)
                """
            )

        } catch {

            errorMessage =
                error.localizedDescription

            print(
                """
                [NOVA STORE] Failed to load data:
                \(error)
                """
            )
        }
    }

    // MARK: - Force Refresh

    func forceRefresh() async {

        await refresh(
            force: true
        )
    }

    // MARK: - Find App

    func app(
        id: String?
    ) -> NOVAApp? {

        guard
            let id
        else {
            return nil
        }

        return apps.first {
            $0.id == id
        }
    }

    // MARK: - Fetch Store File

    private func fetch<T: Decodable>(
        _ filename: String
    ) async throws -> T {

        let cleanFilename =
            filename
                .trimmingCharacters(
                    in:
                        CharacterSet(
                            charactersIn:
                                "/"
                        )
                )

        guard
            !cleanFilename.isEmpty
        else {

            throw NOVAStoreError
                .invalidFileName
        }

        guard
            let token =
                NOVAAuthService.shared.token
        else {

            throw NOVAAuthError
                .notLoggedIn
        }

        guard
            let url =
                URL(
                    string:
                        "\(baseURL.absoluteString)/v1/store/\(cleanFilename)"
                )
        else {

            throw NOVAAuthError
                .invalidURL
        }

        // MARK: Request

        var request =
            URLRequest(
                url:
                    url
            )

        request.httpMethod =
            "GET"

        request.cachePolicy =
            .reloadIgnoringLocalCacheData

        request.timeoutInterval =
            20

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField:
                "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        // MARK: Network

        let (
            data,
            response
        ) =
            try await URLSession.shared
                .data(
                    for:
                        request
                )

        guard
            let http =
                response
                    as? HTTPURLResponse
        else {

            throw NOVAAuthError
                .invalidResponse
        }

        // MARK: Status

        switch
            http.statusCode {

        case 200...299:

            break

        case 401,
             403:

            // الجلسة انتهت أو غير صالحة
            await NOVAAuthService.shared
                .validateSession()

            throw NOVAAuthError
                .notLoggedIn

        case 404:

            throw NOVAStoreError
                .fileNotFound(
                    cleanFilename
                )

        case 500...599:

            throw NOVAStoreError
                .serverError(
                    http.statusCode
                )

        default:

            throw NOVAStoreError
                .httpError(
                    http.statusCode
                )
        }

        // MARK: Decode

        do {

            return try decoder.decode(
                T.self,
                from:
                    data
            )

        } catch {

            print(
                """
                [NOVA STORE] JSON decode failed
                File: \(cleanFilename)
                Error: \(error)
                """
            )

            throw NOVAStoreError
                .invalidData(
                    cleanFilename
                )
        }
    }
}

// MARK: - Store Errors

enum NOVAStoreError:
    LocalizedError {

    case invalidFileName

    case fileNotFound(
        String
    )

    case httpError(
        Int
    )

    case serverError(
        Int
    )

    case invalidData(
        String
    )

    var errorDescription:
        String? {

        switch self {

        case .invalidFileName:

            return
                "اسم ملف المتجر غير صحيح."

        case .fileNotFound(
            let filename
        ):

            return
                "ملف \(filename) غير موجود في NOVA-STORE."

        case .httpError(
            let status
        ):

            return
                "تعذر تحميل بيانات المتجر. رمز الخادم: \(status)."

        case .serverError(
            let status
        ):

            return
                "خادم NOVA STORE يواجه مشكلة مؤقتة. رمز الخادم: \(status)."

        case .invalidData(
            let filename
        ):

            return
                "بيانات ملف \(filename) غير صالحة."
        }
    }
}
