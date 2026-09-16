import SwiftUI
import UniformTypeIdentifiers

struct NOVAInlineCertificateImportView: View {
    @EnvironmentObject private var certStore: CertificateStore
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.forgeTheme) private var T

    @State private var showP12Importer = false
    @State private var showProfileImporter = false
    @State private var showPasswordSheet = false
    @State private var showInfoSheet = false
    @State private var showActions = false
    @State private var errorMessage: String?

    @State private var p12Data: Data?
    @State private var p12Filename = "certificate.p12"
    @State private var profileData: Data?
    @State private var profileFilename = "profile.mobileprovision"
    @State private var certificatePassword = "1"

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if certStore.selected == nil {
                showP12Importer = true
            } else {
                showActions = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(T.accent.opacity(0.13))
                        .frame(width: 52, height: 52)
                    Image(systemName: certStore.selected == nil ? "key.fill" : "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(T.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(certStore.selected == nil ? "استيراد شهادة" : (certStore.selected?.displayName ?? "الشهادة"))
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
        .fileImporter(
            isPresented: $showP12Importer,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleP12Result(result)
        }
        .fileImporter(
            isPresented: $showProfileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleProfileResult(result)
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
            NOVACertificateInfoSheet()
                .liquidGlassSheet()
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
            Button("حسناً", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "حدث خطأ غير معروف.")
        }
    }

    private func handleP12Result(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard url.pathExtension.lowercased() == "p12" else {
                    throw ImportError.invalidP12
                }
                p12Data = data
                p12Filename = url.lastPathComponent
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showProfileImporter = true
                }
            } catch {
                errorMessage = "تعذر قراءة ملف P12."
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = "تعذر اختيار ملف P12."
            }
        }
    }

    private func handleProfileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard url.pathExtension.lowercased() == "mobileprovision" else {
                    throw ImportError.invalidProfile
                }
                profileData = data
                profileFilename = url.lastPathComponent
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    certificatePassword = "1"
                    showPasswordSheet = true
                }
            } catch {
                errorMessage = "تعذر قراءة ملف البروفايل."
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = "تعذر اختيار ملف البروفايل."
            }
        }
    }

    private func importCertificate() {
        let finalPassword = certificatePassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "1"
            : certificatePassword

        guard let p12Data, let profileData else {
            errorMessage = "اختر ملف P12 وملف البروفايل أولاً."
            return
        }

        showPasswordSheet = false

        Task { @MainActor in
            do {
                let certificate = try certStore.importRemoteCertificate(
                    data: p12Data,
                    filename: p12Filename,
                    password: finalPassword
                )

                do {
                    _ = try profileStore.importRemoteProfile(
                        data: profileData,
                        filename: profileFilename
                    )
                } catch {
                    certStore.delete(certificate)
                    throw error
                }

                resetPending()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteCertificate() {
        if let selected = certStore.selected {
            certStore.delete(selected)
        }
    }

    private func resetPending() {
        p12Data = nil
        profileData = nil
        p12Filename = "certificate.p12"
        profileFilename = "profile.mobileprovision"
        certificatePassword = "1"
    }

    private func certificateValidityText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days <= 0 { return "منتهية الصلاحية" }
        return "متبقي \(days) يوم"
    }

    private enum ImportError: LocalizedError {
        case invalidP12
        case invalidProfile

        var errorDescription: String? {
            switch self {
            case .invalidP12: return "الملف المختار ليس ملف P12 صالحاً."
            case .invalidProfile: return "الملف المختار ليس Provisioning Profile صالحاً."
            }
        }
    }
}
