import SwiftUI
import UniformTypeIdentifiers

struct NOVAInlineCertificateImportView: View {
    @EnvironmentObject private var certStore: CertificateStore
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.forgeTheme) private var T
    @AppStorage("app.language") private var languageCode = AppLanguage.english.rawValue

    private enum ImportStage {
        case p12
        case profile
    }

    @State private var showFileImporter = false
    @State private var showProfileStep = false
    @State private var importStage: ImportStage = .p12
    @State private var showPasswordSheet = false
    @State private var showInfoSheet = false
    @State private var showActions = false
    @State private var errorMessage: String?

    @State private var p12Data: Data?
    @State private var p12Filename = "certificate.p12"
    @State private var profileData: Data?
    @State private var profileFilename = "profile.mobileprovision"
    @State private var certificatePassword = "1"

    private static let p12UTType =
        UTType(filenameExtension: "p12") ?? .data

    private static let mobileProvisionUTType =
        UTType(filenameExtension: "mobileprovision") ?? .data

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            if certStore.selected == nil {
                importStage = .p12
                showFileImporter = true
            } else {
                showActions = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(T.accent.opacity(0.13))
                        .frame(width: 52, height: 52)

                    Image(
                        systemName: certStore.selected == nil
                            ? "key.fill"
                            : "checkmark.seal.fill"
                    )
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(T.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        certStore.selected == nil
                            ? "استيراد شهادة"
                            : (certStore.selected?.displayName ?? "الشهادة")
                    )
                    .font(T.sans(16, .bold))
                    .foregroundStyle(T.ink)
                    .lineLimit(1)

                    if let cert = certStore.selected {
                        Text(certificateValidityText(cert.notAfter))
                            .font(T.mono(10, .medium))
                            .foregroundStyle(T.ink3)
                            .lineLimit(1)
                    } else {
                        Text("اختر ملف P12 وملف البروفايل")
                            .font(T.mono(10, .medium))
                            .foregroundStyle(T.ink3)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(T.ink3)
            }
            .padding(.horizontal, 16)
            .frame(height: 70)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.button, cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(T.rule, lineWidth: AppStroke.hairline)
            }
        }
        .buttonStyle(GlassTactileButtonStyle())
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)

        // IMPORTANT: use ONE fileImporter for both files.
        // Multiple fileImporter modifiers on the same view can cause the
        // second importer to replace/intercept the first presentation.
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: importStage == .p12
                ? [Self.p12UTType]
                : [Self.mobileProvisionUTType],
            allowsMultipleSelection: false
        ) { result in
            handleFileResult(result)
        }
        .sheet(isPresented: $showProfileStep) {
            profileStepSheet
                .liquidGlassSheet()
        }
        .sheet(isPresented: $showPasswordSheet) {
            NOVACertificatePasswordSheet(
                password: $certificatePassword,
                onCancel: {
                    resetPending()
                },
                onImport: {
                    importCertificate()
                }
            )
            .liquidGlassSheet()
        }
        .sheet(isPresented: $showInfoSheet) {
            if let certificate = certStore.selected {
                NOVACertificateInfoSheet(
                    certificate: certificate,
                    profile: profileStore.selected,
                    languageCode: languageCode
                )
                .liquidGlassSheet()
            }
        }
        .confirmationDialog(
            "الشهادة",
            isPresented: $showActions,
            titleVisibility: .visible
        ) {
            Button("عرض معلومات الشهادة") {
                showInfoSheet = true
            }

            Button("مسح الشهادة", role: .destructive) {
                deleteCertificate()
            }

            Button("إلغاء", role: .cancel) { }
        }
        .alert(
            "استيراد الشهادة",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("حسناً", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "حدث خطأ غير معروف.")
        }
    }

    private var profileStepSheet: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(T.accent)

            Text("تم اختيار ملف P12")
                .font(T.sans(20, .bold))
                .foregroundStyle(T.ink)

            Text("الآن اختر ملف Provisioning Profile بامتداد .mobileprovision")
                .font(T.mono(11, .medium))
                .foregroundStyle(T.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                showProfileStep = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    importStage = .profile
                    showFileImporter = true
                }
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("اختيار ملف البروفايل")
                }
                .font(T.sans(16, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(T.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button("إلغاء", role: .cancel) {
                showProfileStep = false
                resetPending()
            }
            .font(T.sans(14, .medium))
            .foregroundStyle(T.ink3)
        }
        .padding(24)
    }

    // MARK: - File Import

    private func handleFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            readSelectedFile(url)

        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = importStage == .p12
                    ? "تعذر اختيار ملف P12."
                    : "تعذر اختيار ملف البروفايل."
            }
        }
    }

    private func readSelectedFile(_ url: URL) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            switch importStage {
            case .p12:
                guard !data.isEmpty else {
                    throw ImportError.invalidP12
                }

                p12Data = data
                p12Filename = url.lastPathComponent

                // Do not stack another document picker immediately.
                // Show a clear second step so the user knows exactly what to choose.
                importStage = .profile
                showProfileStep = true

            case .profile:
                guard !data.isEmpty else {
                    throw ImportError.invalidProfile
                }

                profileData = data
                profileFilename = url.lastPathComponent
                certificatePassword = "1"

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showPasswordSheet = true
                }
            }
        } catch let error as ImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = importStage == .p12
                ? "تعذر قراءة ملف P12."
                : "تعذر قراءة ملف البروفايل."
        }
    }

    // MARK: - Import

    private func importCertificate() {
        let finalPassword = certificatePassword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
            ? "1"
            : certificatePassword

        guard let p12Data, let profileData else {
            errorMessage = "اختر ملف P12 وملف البروفايل أولاً."
            return
        }

        showPasswordSheet = false

        Task { @MainActor in
            let certificateResult = certStore.importRemoteCertificate(
                data: p12Data,
                filename: p12Filename,
                password: finalPassword
            )

            switch certificateResult {
            case .failure(let error):
                errorMessage = error.localizedDescription

            case .success(let certificate):
                let profileResult = profileStore.importRemoteProfile(
                    data: profileData,
                    filename: profileFilename
                )

                switch profileResult {
                case .success:
                    resetPending()

                case .failure(let error):
                    // Roll back only the certificate imported by this operation.
                    certStore.delete(certificate)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Certificate Actions

    private func deleteCertificate() {
        guard let selected = certStore.selected else { return }
        certStore.delete(selected)
        resetPending()
    }

    private func resetPending() {
        p12Data = nil
        profileData = nil
        p12Filename = "certificate.p12"
        profileFilename = "profile.mobileprovision"
        certificatePassword = "1"
        importStage = .p12
    }

    // MARK: - Helpers

    private func certificateValidityText(_ date: Date?) -> String {
        guard let date else {
            return "المدة غير متوفرة"
        }

        let days = Calendar.current.dateComponents(
            [.day],
            from: .now,
            to: date
        ).day ?? 0

        if days <= 0 {
            return "منتهية الصلاحية"
        }

        return "متبقي \(days) يوم"
    }

    private enum ImportError: LocalizedError {
        case invalidP12
        case invalidProfile

        var errorDescription: String? {
            switch self {
            case .invalidP12:
                return "الملف المختار ليس ملف P12 صالحاً."
            case .invalidProfile:
                return "الملف المختار ليس Provisioning Profile صالحاً."
            }
        }
    }
}
