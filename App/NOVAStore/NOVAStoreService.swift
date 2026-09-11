import Foundation
import Combine

@MainActor
final class NOVAStoreService: ObservableObject {
    
    static let shared = NOVAStoreService()
    
    // يجب أن يكون مستودع NOVA-STORE عاماً حتى يستطيع التطبيق
    // تحميل ملفات JSON مباشرة من GitHub.
    private let baseURL = URL(
        string: "https://raw.githubusercontent.com/GFIOPZ/NOVA-STORE/main/"
    )!
    
    // MARK: - Published Data
    
    @Published private(set) var apps: [NOVAApp] = []
    @Published private(set) var banners: [NOVABanner] = []
    @Published private(set) var categories: [NOVACategory] = []
    @Published private(set) var sources: [NOVASource] = []
    @Published private(set) var settings: NOVAStoreSettings?
    
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private
    
    private let decoder = JSONDecoder()
    private var loaded = false
    
    private init() {}
    
    // MARK: - Refresh
    
    func refresh(force: Bool = false) async {
        if loaded && !force {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            async let appsResponse: NOVAAppsResponse =
                fetch("apps.json")
            
            async let bannersResponse: NOVABannersResponse =
                fetch("banners.json")
            
            async let categoriesResponse: NOVACategoriesResponse =
                fetch("categories.json")
            
            async let sourcesResponse: NOVASourcesResponse =
                fetch("sources.json")
            
            async let settingsResponse: NOVASettingsResponse =
                fetch("settings.json")
            
            let (
                appsResponseValue,
                bannersResponseValue,
                categoriesResponseValue,
                sourcesResponseValue,
                settingsResponseValue
            ) = try await (
                appsResponse,
                bannersResponse,
                categoriesResponse,
                sourcesResponse,
                settingsResponse
            )
            
            // التطبيقات المفعلة فقط
            apps = appsResponseValue.apps.filter { app in
                app.enabled
            }
            
            // البنرات المفعلة وترتيبها حسب sort_order
            banners = bannersResponseValue.banners
                .filter { banner in
                    banner.enabled
                }
                .sorted { first, second in
                    first.sortOrder < second.sortOrder
                }
            
            // التصنيفات المفعلة فقط
            categories = categoriesResponseValue.categories
                .filter { category in
                    category.enabled
                }
            
            // المصادر المفعلة والتي تظهر داخل المتجر
            sources = sourcesResponseValue.sources
                .filter { source in
                    source.enabled && source.showInStore
                }
            
            // إعدادات المتجر
            settings = settingsResponseValue.store
            
            loaded = true
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Find App
    
    func app(id: String?) -> NOVAApp? {
        guard let id else {
            return nil
        }
        
        return apps.first {
            $0.id == id
        }
    }
    
    // MARK: - Fetch JSON
    
    private func fetch<T: Decodable>(
        _ filename: String
    ) async throws -> T {
        
        let url = baseURL.appendingPathComponent(filename)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode(T.self, from: data)
    }
}
