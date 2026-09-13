import Foundation
import Security

enum NOVAKeychain {

    private static let service =
        "com.nova.store.auth"

    static func save(
        _ value: String,
        account: String
    ) {

        delete(account: account)

        let query: [String: Any] = [

            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account,

            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,

            kSecValueData as String:
                Data(value.utf8)
        ]

        SecItemAdd(
            query as CFDictionary,
            nil
        )
    }

    static func load(
        account: String
    ) -> String? {

        let query: [String: Any] = [

            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account,

            kSecReturnData as String:
                true,

            kSecMatchLimit as String:
                kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &result
            )

        guard
            status == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }

        return String(
            data: data,
            encoding: .utf8
        )
    }

    static func delete(
        account: String
    ) {

        let query: [String: Any] = [

            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account
        ]

        SecItemDelete(
            query as CFDictionary
        )
    }
}
