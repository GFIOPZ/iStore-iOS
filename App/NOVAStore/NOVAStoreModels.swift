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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subtitle
        case description
        case icon
        case version
        case size
        case categoryID = "category_id"
        case sourceID = "source_id"
        case sourceType = "source_type"
        case ipaURL = "ipa_url"
        case screenshots
        case featured
        case enabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NOVAAppsResponse: Codable {
    let version: Int
    let updatedAt: String
    let apps: [NOVAApp]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case apps
    }
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

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image_url"
        case title
        case subtitle
        case description
        case actionType = "action_type"
        case appID = "app_id"
        case externalURL = "external_url"
        case buttonTitle = "button_title"
        case sortOrder = "sort_order"
        case enabled
    }
}

struct NOVABannersResponse: Codable {
    let version: Int
    let updatedAt: String
    let banners: [NOVABanner]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case banners
    }
}

// MARK: - Category

struct NOVACategory: Codable, Identifiable, Hashable {
    let id: String
    let nameAR: String
    let nameEN: String
    let icon: String
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nameAR = "name_ar"
        case nameEN = "name_en"
        case icon
        case enabled
    }
}

struct NOVACategoriesResponse: Codable {
    let version: Int
    let updatedAt: String
    let categories: [NOVACategory]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case categories
    }
}

// MARK: - Source

struct NOVASource: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let repoURL: String
    let type: String
    let enabled: Bool
    let showInStore: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case repoURL = "repo_url"
        case type
        case enabled
        case showInStore = "show_in_store"
    }
}

struct NOVASourcesResponse: Codable {
    let version: Int
    let updatedAt: String
    let sources: [NOVASource]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case sources
    }
}

// MARK: - Store Settings

struct NOVAStoreSettings: Codable, Hashable {
    let name: String
    let supportChannel: String
    let latestAppsLimit: Int
    let maintenance: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case supportChannel = "support_channel"
        case latestAppsLimit = "latest_apps_limit"
        case maintenance
    }
}

struct NOVASettingsResponse: Codable {
    let version: Int
    let updatedAt: String
    let store: NOVAStoreSettings

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case store
    }
}
