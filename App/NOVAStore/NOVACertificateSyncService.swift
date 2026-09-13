import Foundation

@MainActor
final class NOVACertificateSyncService {
    static let shared = NOVACertificateSyncService()

    private init() {}

    func sync(
        auth: NOVAAuthService,
        certificates: CertificateStore,
        profiles: ProfileStore
    ) async {
        guard auth.isLoggedIn else { return }

        do {
            // fetchCertificate() ترجع NOVACertificatePackage
            // مباشرة، لذلك لا نستخدم guard let هنا.
            let package = try await auth.fetchCertificate()

            guard let p12Data = Data(base64Encoded: package.p12Base64) else {
                print("NOVA: Invalid P12 Base64")
                return
            }

            guard let profileData = Data(base64Encoded: package.profileBase64) else {
                print("NOVA: Invalid profile Base64")
                return
            }

            let certificateResult =
                certificates.importRemoteCertificate(
                    data: p12Data,
                    filename: package.p12Filename,
                    password: package.p12Password
                )

            switch certificateResult {
            case .success(let certificate):
                print(
                    "NOVA: Certificate synced:",
                    certificate.displayName
                )

            case .failure(let error):
                print(
                    "NOVA: Certificate sync failed:",
                    error.localizedDescription
                )
            }

            let profileResult =
                profiles.importRemoteProfile(
                    data: profileData,
                    filename: package.profileFilename
                )

            switch profileResult {
            case .success(let profile):
                print(
                    "NOVA: Profile synced:",
                    profile.displayName
                )

            case .failure(let error):
                print(
                    "NOVA: Profile sync failed:",
                    error.localizedDescription
                )
            }

        } catch {
            print(
                "NOVA: Certificate request failed:",
                error.localizedDescription
            )
        }
    }
}
