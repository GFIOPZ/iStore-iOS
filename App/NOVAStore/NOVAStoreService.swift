import Foundation

@MainActor
final class NOVAStoreService: ObservableObject {
    static let shared = NOVAStoreService()

    // IMPORTANT:
    // Direct JSON fetching requires the NOVA-STORE repository to be PUBLIC.
    // If the repository stays private, an authenticated backend is required.
    private let baseURL = URL(string: "https://raw.githubusercontent.com/GFIOPZ/NOVA-STORE/main/")!

    @Published private(set) var apps: [NOVAApp] = []
    @Published private(set) var banners: [NOVABanner] = []
    @Published private(set) var categories: [NOVACategory] = []
    @Published private(set) var sources: [NOVASource] = []
    @Published private(set) var settings: NOVAStoreSettings?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let decoder = JSONDecoder()
    private var loaded = false

    private init() {}

    func refresh(force: Bool = false) async {
        if loaded && !force { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let appsResponse: NOVAAppsResponse = fetch("apps.json")
            async let bannersResponse: NOVABannersResponse = fetch("banners.json")
            async let categoriesResponse: NOVACategoriesResponse = fetch("categories.json")
            async let sourcesResponse: NOVASourcesResponse = fetch("sources.json")
            async let settingsResponse: NOVASettingsResponse = fetch("settings.json")

            let (a, b, c, s, settings) = try await (
                appsResponse,
                bannersResponse,
                categoriesResponse,
                sourcesResponse,
                settingsResponse
            )

            apps = a.apps.filter { $0.enabled != false }
            banners = b.banners
                .filter { $0.enabled != false }
                .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            categories = c.categories.filter(\.enabled)
            sources = s.sources.filter { $0.enabled != false && $0.showInStore != false }
            self.settings = settings.store
            loaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func app(id: String?) -> NOVAApp? {
        guard let id else { return nil }
        return apps.first { $0.id == id }
    }

    private func fetch<T: Decodable>(_ filename: String) async throws -> T {
        let url = baseURL.appendingPathComponent(filename)
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }
}