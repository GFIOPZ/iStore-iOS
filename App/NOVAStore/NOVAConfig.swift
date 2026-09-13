import Foundation

enum NOVAConfig {

    static let apiBaseURL =
        "https://nova-ipa.hassanyipa.workers.dev"

    static var isValid: Bool {

        guard
            let url = URL(
                string: apiBaseURL
            ),
            url.scheme == "https",
            url.host != nil
        else {
            return false
        }

        return true
    }
}
