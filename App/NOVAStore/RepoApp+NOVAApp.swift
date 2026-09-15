import Foundation

extension RepoApp {
    /// Builds a `RepoApp` from a manually curated `NOVAApp` (added via the
    /// admin control panel's apps.json). This lets manually-added apps flow
    /// through the exact same aggregated list, the exact same
    /// `RepoAppDetailSheet`, and the exact same `RepositoryStore.download`
    /// sign+install pipeline as apps pulled from real AltStore sources —
    /// instead of a separate, unstyled screen with a plain file download.
    init(novaApp app: NOVAApp) {
        self.name = app.name
        self.bundleIdentifier = app.id
        self.developerName = app.developerName.isEmpty ? nil : app.developerName
        self.localizedDescription = app.description.isEmpty ? nil : app.description
        self.category = app.categoryID.isEmpty ? nil : app.categoryID
        self.iconURL = URL(string: app.icon)
        self.urlSchemes = app.urlScheme.isEmpty ? [] : [app.urlScheme]
        self.screenshotURLs = app.screenshots.compactMap(URL.init(string:))
        self.version = app.version.isEmpty ? nil : app.version
        self.downloadURL = URL(string: app.ipaURL)
        self.size = Self.parseSizeInBytes(app.size)
        self.versions = []
    }

    /// Parses free-text sizes like "45 MB" or "1.2 GB" (as typed in the admin
    /// panel) into raw bytes. Returns nil if the text isn't parseable — the
    /// UI already treats a missing size as "—".
    private static func parseSizeInBytes(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let numberPart = trimmed.prefix { "0123456789.".contains($0) }
        guard let value = Double(numberPart) else { return nil }

        let unitPart = trimmed.dropFirst(numberPart.count)
            .trimmingCharacters(in: .whitespaces)
            .uppercased()

        let multiplier: Double
        switch unitPart {
        case "GB", "G": multiplier = 1_000_000_000
        case "KB", "K": multiplier = 1_000
        default: multiplier = 1_000_000 // مافيه وحدة أو "MB" — نفترضها ميغابايت
        }
        return Int64(value * multiplier)
    }
}
