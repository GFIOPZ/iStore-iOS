import Foundation
import Combine

@MainActor
final class NOVAStoreService: ObservableObject {
    static let shared = NOVAStoreService()

    @Published private(set) var apps: [NOVAApp] = []
    @Published private(set) var banners: [NOVABanner] = []
    @Published private(set) var categories: [NOVACategory] = []
    @Published private(set) var sources: [NOVASource] = []
    @Published private(set) var settings: NOVAStoreSettings?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let baseURL = URL(string: "https://nova-ipa.hassanyipa.workers.dev")!
    private let decoder = JSONDecoder()
    private var loaded = false
    private init() {}

    func refresh(force: Bool = false) async {
        guard !loaded || force else { return }

        // إذا كان الـ preload شغالاً، لا نبدأ طلبات ثانية لنفس البيانات.
        if isLoading {
            while isLoading && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return
        }

        guard NOVAAuthService.shared.isLoggedIn else {
            errorMessage = "يجب تسجيل الدخول أولاً."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var failures: [String] = []

        // تحميل ملفات المتجر بالتوازي حتى يكون الـ preload فعلياً سريعاً.
        async let appsResult: Result<NOVAAppsResponse, Error> = fetchResult("apps.json")
        async let bannersResult: Result<NOVABannersResponse, Error> = fetchResult("banners.json")
        async let categoriesResult: Result<NOVACategoriesResponse, Error> = fetchResult("categories.json")
        async let sourcesResult: Result<NOVASourcesResponse, Error> = fetchResult("sources.json")
        async let settingsResult: Result<NOVASettingsResponse, Error> = fetchResult("settings.json")

        let appsValue = await appsResult
        switch appsValue {
        case .success(let value):
            apps = value.apps.filter { $0.enabled }.sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.updatedAt > $1.updatedAt
            }
        case .failure: failures.append("apps.json")
        }

        let bannersValue = await bannersResult
        switch bannersValue {
        case .success(let value):
            banners = value.banners.filter { $0.enabled }.sorted { $0.sortOrder < $1.sortOrder }
        case .failure: failures.append("banners.json")
        }

        let categoriesValue = await categoriesResult
        switch categoriesValue {
        case .success(let value): categories = value.categories.filter { $0.enabled }
        case .failure: failures.append("categories.json")
        }

        let sourcesValue = await sourcesResult
        switch sourcesValue {
        case .success(let value): sources = value.sources.filter { $0.enabled && $0.showInStore }
        case .failure: failures.append("sources.json")
        }

        let settingsValue = await settingsResult
        switch settingsValue {
        case .success(let value): settings = value.store
        case .failure: failures.append("settings.json")
        }

        loaded = true

        if !failures.isEmpty {
            errorMessage = "تعذر تحميل بعض بيانات المتجر: \(failures.joined(separator: ", "))"
        }

        print("[NOVA STORE] Apps: \(apps.count), Banners: \(banners.count), Categories: \(categories.count), Sources: \(sources.count), Settings: \(settings != nil)")
    }

    func forceRefresh() async { await refresh(force: true) }

    func app(id: String?) -> NOVAApp? {
        guard let id, !id.isEmpty else { return nil }
        return apps.first { $0.id == id }
    }

    private func fetchResult<T: Decodable>(_ filename: String) async -> Result<T, Error> {
        do { return .success(try await fetch(filename)) }
        catch { return .failure(error) }
    }

    private func fetch<T: Decodable>(_ filename: String) async throws -> T {
        let clean = filename.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !clean.isEmpty else { throw NOVAStoreError.invalidFileName }
        guard let token = NOVAAuthService.shared.token else { throw NOVAAuthError.notLoggedIn }
        guard let url = URL(string: "\(baseURL.absoluteString)/v1/store/\(clean)") else { throw NOVAAuthError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NOVAAuthError.invalidResponse }

        switch http.statusCode {
        case 200...299: break
        case 401, 403:
            await NOVAAuthService.shared.validateSession()
            throw NOVAAuthError.notLoggedIn
        case 404: throw NOVAStoreError.fileNotFound(clean)
        case 500...599: throw NOVAStoreError.serverError(http.statusCode)
        default: throw NOVAStoreError.httpError(http.statusCode)
        }

        do { return try decoder.decode(T.self, from: data) }
        catch {
            print("[NOVA STORE] JSON decode failed for \(clean): \(error)")
            throw NOVAStoreError.invalidData(clean)
        }
    }
}

enum NOVAStoreError: LocalizedError {
    case invalidFileName
    case fileNotFound(String)
    case httpError(Int)
    case serverError(Int)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .invalidFileName: return "اسم ملف المتجر غير صحيح."
        case .fileNotFound(let filename): return "ملف \(filename) غير موجود في NOVA-STORE."
        case .httpError(let status): return "تعذر تحميل بيانات المتجر. رمز الخادم: \(status)."
        case .serverError(let status): return "خادم NOVA STORE يواجه مشكلة مؤقتة. رمز الخادم: \(status)."
        case .invalidData(let filename): return "بيانات ملف \(filename) غير صالحة."
        }
    }
}
