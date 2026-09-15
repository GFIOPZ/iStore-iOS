import Foundation

// MARK: - App

struct NOVAApp: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let description: String
    let icon: String
    let version: String
    let size: String
    let categoryID: String
    let sourceID: String
    let sourceType: String
    let ipaURL: String
    let screenshots: [String]
    let featured: Bool
    let enabled: Bool
    let createdAt: String
    let updatedAt: String
    let developerName: String
    let urlScheme: String
    let tags: [String]
    let badge: String
    let sortOrder: Int
    let showInHome: Bool
    let showInApps: Bool
    let exclusive: Bool
    let minIOS: String

    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, description, icon, version, size
        case categoryID = "category_id"
        case sourceID = "source_id"
        case sourceType = "source_type"
        case ipaURL = "ipa_url"
        case screenshots, featured, enabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case developerName = "developer_name"
        case urlScheme = "url_scheme"
        case tags, badge
        case sortOrder = "sort_order"
        case showInHome = "show_in_home"
        case showInApps = "show_in_apps"
        case exclusive
        case minIOS = "min_ios"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.string(c, .id, fallback: "")
        name = Self.string(c, .name, fallback: "Untitled")
        subtitle = Self.string(c, .subtitle)
        description = Self.string(c, .description)
        icon = Self.string(c, .icon)
        version = Self.string(c, .version)
        size = Self.string(c, .size)
        categoryID = Self.string(c, .categoryID, fallback: "other")
        sourceID = Self.string(c, .sourceID, fallback: "nova-store")
        sourceType = Self.string(c, .sourceType, fallback: "official")
        ipaURL = Self.string(c, .ipaURL)
        screenshots = (try? c.decodeIfPresent([String].self, forKey: .screenshots)) ?? []
        featured = Self.bool(c, .featured, fallback: false)
        enabled = Self.bool(c, .enabled, fallback: true)
        createdAt = Self.string(c, .createdAt)
        updatedAt = Self.string(c, .updatedAt)
        developerName = Self.string(c, .developerName)
        urlScheme = Self.string(c, .urlScheme)
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        badge = Self.string(c, .badge)
        sortOrder = Self.int(c, .sortOrder, fallback: 0)
        showInHome = Self.bool(c, .showInHome, fallback: true)
        showInApps = Self.bool(c, .showInApps, fallback: true)
        exclusive = Self.bool(c, .exclusive, fallback: true)
        minIOS = Self.string(c, .minIOS)
    }

    private static func string(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, fallback: String = "") -> String {
        (try? c.decodeIfPresent(String.self, forKey: key)) ?? fallback
    }

    private static func bool(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, fallback: Bool) -> Bool {
        if let value = try? c.decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        if let value = try? c.decodeIfPresent(String.self, forKey: key) {
            return ["true", "1", "yes", "on"].contains(value.lowercased())
        }
        return fallback
    }

    private static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, fallback: Int) -> Int {
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(String.self, forKey: key), let number = Int(value) { return number }
        return fallback
    }
}

struct NOVAAppsResponse: Codable {
    let version: Int
    let updatedAt: String
    let apps: [NOVAApp]
    enum CodingKeys: String, CodingKey { case version, updatedAt = "updated_at", apps }
}

// MARK: - Banner

struct NOVABanner: Codable, Identifiable, Hashable {
    let id: String
    let imageURL: String
    let title: String
    let subtitle: String
    let description: String
    let actionType: String
    let appID: String?
    let externalURL: String
    let buttonTitle: String
    let sortOrder: Int
    let enabled: Bool
    let showButton: Bool
    let openOnTap: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image_url"
        case title, subtitle, description
        case actionType = "action_type"
        case appID = "app_id"
        case externalURL = "external_url"
        case buttonTitle = "button_title"
        case sortOrder = "sort_order"
        case enabled
        case showButton = "show_button"
        case openOnTap = "open_on_tap"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        imageURL = (try? c.decodeIfPresent(String.self, forKey: .imageURL)) ?? ""
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        subtitle = (try? c.decodeIfPresent(String.self, forKey: .subtitle)) ?? ""
        description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        actionType = (try? c.decodeIfPresent(String.self, forKey: .actionType)) ?? "none"
        appID = try? c.decodeIfPresent(String.self, forKey: .appID)
        externalURL = (try? c.decodeIfPresent(String.self, forKey: .externalURL)) ?? ""
        buttonTitle = (try? c.decodeIfPresent(String.self, forKey: .buttonTitle)) ?? "عرض"
        sortOrder = (try? c.decodeIfPresent(Int.self, forKey: .sortOrder)) ?? 0
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? true
        showButton = (try? c.decodeIfPresent(Bool.self, forKey: .showButton)) ?? true
        openOnTap = (try? c.decodeIfPresent(Bool.self, forKey: .openOnTap)) ?? true
    }
}

struct NOVABannersResponse: Codable {
    let version: Int
    let updatedAt: String
    let banners: [NOVABanner]
    enum CodingKeys: String, CodingKey { case version, updatedAt = "updated_at", banners }
}

// MARK: - Category

struct NOVACategory: Codable, Identifiable, Hashable {
    let id: String
    let nameAR: String
    let nameEN: String
    let icon: String
    let enabled: Bool
    enum CodingKeys: String, CodingKey { case id, nameAR = "name_ar", nameEN = "name_en", icon, enabled }
}

struct NOVACategoriesResponse: Codable {
    let version: Int
    let updatedAt: String
    let categories: [NOVACategory]
    enum CodingKeys: String, CodingKey { case version, updatedAt = "updated_at", categories }
}

// MARK: - Source

struct NOVASource: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let repoURL: String
    let type: String
    let enabled: Bool
    let showInStore: Bool
    enum CodingKeys: String, CodingKey { case id, name, repoURL = "repo_url", type, enabled, showInStore = "show_in_store" }
}

struct NOVASourcesResponse: Codable {
    let version: Int
    let updatedAt: String
    let sources: [NOVASource]
    enum CodingKeys: String, CodingKey { case version, updatedAt = "updated_at", sources }
}

// MARK: - Store Settings

struct NOVAStoreSettings: Codable, Hashable {
    let name: String
    let supportChannel: String
    let latestAppsLimit: Int
    let maintenance: Bool
    enum CodingKeys: String, CodingKey { case name, supportChannel = "support_channel", latestAppsLimit = "latest_apps_limit", maintenance }
}

struct NOVASettingsResponse: Codable {
    let version: Int
    let updatedAt: String
    let store: NOVAStoreSettings
    enum CodingKeys: String, CodingKey { case version, updatedAt = "updated_at", store }
}
