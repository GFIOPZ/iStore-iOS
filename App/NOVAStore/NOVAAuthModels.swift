import Foundation

struct NOVALoginRequest: Codable {

    let username: String
    let password: String
    let code: String
    let deviceID: String

    enum CodingKeys: String, CodingKey {

        case username
        case password
        case code

        case deviceID = "device_id"
    }
}


struct NOVAUserSession: Codable, Equatable {

    let sessionToken: String
    let username: String
    let displayName: String
    let subscriptionID: String
    let certificateID: String?
    let expiresAt: String
    let deviceBound: Bool

    enum CodingKeys: String, CodingKey {

        case sessionToken = "session_token"
        case username

        case displayName = "display_name"

        case subscriptionID =
            "subscription_id"

        case certificateID =
            "certificate_id"

        case expiresAt =
            "expires_at"

        case deviceBound =
            "device_bound"
    }
}


struct NOVALoginResponse: Codable {

    let ok: Bool
    let session: NOVAUserSession?
    let message: String?
}


struct NOVACertificatePackage: Codable {

    let certificateID: String

    let p12Base64: String
    let p12Password: String
    let p12Filename: String

    let profileBase64: String
    let profileFilename: String

    enum CodingKeys: String, CodingKey {

        case certificateID =
            "certificate_id"

        case p12Base64 =
            "p12_base64"

        case p12Password =
            "p12_password"

        case p12Filename =
            "p12_filename"

        case profileBase64 =
            "profile_base64"

        case profileFilename =
            "profile_filename"
    }
}
