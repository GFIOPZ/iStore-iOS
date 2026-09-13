import Foundation
import Combine
import UIKit

@MainActor
final class NOVAAuthService: ObservableObject {

    static let shared = NOVAAuthService()

    @Published private(set) var session: NOVAUserSession?

    private let sessionKey = "nova.session"

    private init() {
        loadSession()
    }

    var isLoggedIn: Bool {
        session != nil
    }

    var token: String? {
        session?.sessionToken
    }

    // MARK: - Device ID

    private var deviceID: String {

        let key = "nova.device.id"

        if let saved =
            UserDefaults.standard.string(forKey: key) {
            return saved
        }

        let id =
            UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString

        UserDefaults.standard.set(id, forKey: key)

        return id
    }

    // MARK: - Load Session

    private func loadSession() {

        guard
            let saved =
                NOVAKeychain.load(
                    account: sessionKey
                ),
            let data =
                saved.data(using: .utf8),
            let decoded =
                try? JSONDecoder().decode(
                    NOVAUserSession.self,
                    from: data
                )
        else {
            return
        }

        session = decoded
    }

    // MARK: - Save Session

    private func saveSession(
        _ newSession: NOVAUserSession
    ) {

        guard
            let data =
                try? JSONEncoder().encode(
                    newSession
                ),
            let value =
                String(
                    data: data,
                    encoding: .utf8
                )
        else {
            return
        }

        NOVAKeychain.save(
            value,
            account: sessionKey
        )

        session = newSession
    }

    // MARK: - Login

    func login(
        username: String,
        password: String,
        code: String
    ) async throws {

        guard
            let url =
                URL(
                    string:
                        "\(NOVAConfig.apiBaseURL)/v1/auth/login"
                )
        else {
            throw NOVAAuthError.invalidURL
        }

        let body =
            NOVALoginRequest(
                username:
                    username.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                password: password,
                code:
                    code.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                deviceID: deviceID
            )

        var request =
            URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        request.httpBody =
            try JSONEncoder().encode(body)

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard
            let http =
                response as? HTTPURLResponse
        else {
            throw NOVAAuthError.invalidResponse
        }

        let result =
            try? JSONDecoder().decode(
                NOVALoginResponse.self,
                from: data
            )

        guard
            (200..<300).contains(
                http.statusCode
            ),
            result?.ok == true,
            let newSession =
                result?.session
        else {

            throw NOVAAuthError.server(
                result?.message
                ?? "بيانات الدخول غير صحيحة."
            )
        }

        saveSession(newSession)
    }

    // MARK: - Validate Session

    func validateSession() async {

        guard let token else {
            return
        }

        guard
            let url =
                URL(
                    string:
                        "\(NOVAConfig.apiBaseURL)/v1/session"
                )
        else {
            return
        }

        var request =
            URLRequest(url: url)

        request.httpMethod = "GET"

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

        do {

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let http =
                    response as? HTTPURLResponse
            else {
                return
            }

            if
                http.statusCode == 401 ||
                http.statusCode == 403
            {
                logout()
                return
            }

            guard
                (200..<300).contains(
                    http.statusCode
                ),
                let result =
                    try? JSONDecoder().decode(
                        NOVALoginResponse.self,
                        from: data
                    ),
                let newSession =
                    result.session
            else {
                return
            }

            saveSession(newSession)

        } catch {
            // لا نمسح الجلسة بسبب انقطاع الإنترنت المؤقت.
        }
    }

    // MARK: - Certificate

    func fetchCertificate()
        async throws
        -> NOVACertificatePackage
    {

        guard let token else {
            throw NOVAAuthError.notLoggedIn
        }

        guard
            let url =
                URL(
                    string:
                        "\(NOVAConfig.apiBaseURL)/v1/certificate"
                )
        else {
            throw NOVAAuthError.invalidURL
        }

        var request =
            URLRequest(url: url)

        request.httpMethod = "GET"

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

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard
            let http =
                response as? HTTPURLResponse
        else {
            throw NOVAAuthError.invalidResponse
        }

        if
            http.statusCode == 401 ||
            http.statusCode == 403
        {
            logout()

            throw NOVAAuthError.notLoggedIn
        }

        guard
            (200..<300).contains(
                http.statusCode
            )
        else {
            throw NOVAAuthError.server(
                "تعذر تحميل الشهادة."
            )
        }

        return try JSONDecoder().decode(
            NOVACertificatePackage.self,
            from: data
        )
    }

    // MARK: - Logout

    func logout() {

        NOVAKeychain.delete(
            account: sessionKey
        )

        session = nil

        NotificationCenter.default.post(
            name: .novaDidLogout,
            object: nil
        )
    }
}


// MARK: - Errors

enum NOVAAuthError: LocalizedError {

    case invalidURL
    case invalidResponse
    case notLoggedIn
    case server(String)

    var errorDescription: String? {

        switch self {

        case .invalidURL:
            return "رابط الخادم غير صحيح."

        case .invalidResponse:
            return "استجابة الخادم غير صحيحة."

        case .notLoggedIn:
            return "يجب تسجيل الدخول أولاً."

        case .server(let message):
            return message
        }
    }
}


// MARK: - Notification

extension Notification.Name {

    static let novaDidLogout =
        Notification.Name(
            "novaDidLogout"
        )
}
