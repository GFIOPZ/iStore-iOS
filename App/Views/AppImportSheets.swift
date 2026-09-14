import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct URLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var T

    @Binding var urlText: String
    let isLoading: Bool
    let importAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(T.accent)
                        .frame(width: 58, height: 58)
                        .glassSurface(.icon, cornerRadius: 19)

                    Text("Import from Link")
                        .font(T.sans(21, .bold))
                        .foregroundStyle(T.ink)

                    Text("Paste the direct IPA link below")
                        .font(T.sans(11, .medium))
                        .foregroundStyle(T.ink3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("IPA / URL")
                        .font(T.sans(12, .semibold))
                        .foregroundStyle(T.ink2)

                    TextField("https://…", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.done)
                        .padding(.horizontal, 15)
                        .frame(height: 54)
                        .glassSurface(.composerField, cornerRadius: 17)
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(T.accent.opacity(0.14), lineWidth: AppStroke.hairline)
                        }
                }
                .padding(.top, 26)

                Button(action: importAction) {
                    HStack(spacing: 9) {
                        if isLoading {
                            ProgressView().tint(T.accent)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }

                        Text(isLoading ? "Importing…" : "Import")
                            .font(T.sans(15, .bold))
                    }
                    .foregroundStyle(T.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .glassSurface(.button, cornerRadius: 18)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(T.accent.opacity(0.22), lineWidth: AppStroke.hairline)
                    }
                }
                .buttonStyle(GlassTactileButtonStyle())
                .disabled(isLoading || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .padding(.top, 14)

                Spacer()
            }
            .padding(.horizontal, 20)
            .background { ForgeBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .floatingGlassBackButton(action: { dismiss() })
        .presentationDetents([.height(310)])
        .presentationDragIndicator(.visible)
        .onChange(of: isLoading) { nowLoading in
            if !nowLoading { dismiss() }
        }
    }
}

struct AppEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var T

    @Binding var appName: String
    @Binding var bundleID: String
    @Binding var version: String
    @Binding var password: String
    let hasSavedPassword: Bool
    let certificateName: String?
    let profileName: String?
    let preflightState: IPAPreflightState
    let isSigning: Bool
    let canSign: Bool
    let dylibURL: URL?
    let iconURL: URL?
    let shareURL: URL?
    @Binding var removeExtensions: Bool
    @Binding var enableDocuments: Bool
    let onChooseIcon: (URL) -> Void
    let onChoosePhoto: (PhotosPickerItem?) -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showIconDocumentPicker = false
    @State private var showDylibFileImporter = false
    @State private var showShareSheet = false
    @State private var showShareError = false
    let onChooseCertificate: () -> Void
    let onChooseProfile: () -> Void
    let onChooseDylib: (URL) -> Void
    let onRemoveDylib: () -> Void
    let onSignOnly: () -> Void
    let onSign: () -> Void
    @State private var showExtensionAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    appHero
                    editFields
                    toolsSection
                    signButton
                }
                .padding(.top, 20)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background { ForgeBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showIconDocumentPicker) {
            ForgeDocumentPicker(contentTypes: [.image], onPick: { urls in
                showIconDocumentPicker = false
                guard let url = urls.first else { return }
                onChooseIcon(url)
            }, onCancel: {
                showIconDocumentPicker = false
            })
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showDylibFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "dylib") ?? .data]
        ) { result in
            if case .success(let url) = result {
                onChooseDylib(url)
            }
        }
        .floatingGlassBackButton(action: { dismiss() })
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedPhoto) { item in
            onChoosePhoto(item)
        }
    }

    private var appHero: some View {
        VStack(spacing: 11) {
            Group {
                if let iconURL, let image = UIImage(contentsOfFile: iconURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(T.accent)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .glassSurface(.hero, cornerRadius: 24)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(T.accent.opacity(0.18), lineWidth: AppStroke.hairline)
            }

            Text(appName.isEmpty ? "Application" : appName)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(T.ink)
                .lineLimit(1)

            if !bundleID.isEmpty {
                Text(bundleID)
                    .font(T.mono(9, .medium))
                    .foregroundStyle(T.ink3)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, T.pad)
    }

    private var editFields: some View {
        VStack(spacing: 0) {
            GlassInputRow(icon: "textformat", label: "App Name", placeholder: "Application name", text: $appName)
            GlassRowDivider()
            GlassInputRow(icon: "curlybraces", label: "Bundle ID", placeholder: "com.example.app", text: $bundleID)
            GlassRowDivider()
            GlassInputRow(icon: "number", label: "Version", placeholder: "1.0", text: $version)
        }
        .glassSurface(.card, cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(T.rule, lineWidth: AppStroke.hairline)
        }
        .padding(.horizontal, T.pad)
    }

    private var toolsSection: some View {
        VStack(spacing: 0) {
            GlassSecondaryButton(
                label: dylibURL == nil ? "Add Dylib" : "Dylib Added",
                systemImage: "puzzlepiece.extension"
            ) {
                showDylibFileImporter = true
            }

            if dylibURL != nil {
                GlassRowDivider()
                GlassSecondaryButton(
                    label: "Remove Dylib",
                    systemImage: "minus.circle",
                    destructive: true
                ) {
                    onRemoveDylib()
                }
            }
        }
        .glassSurface(.card, cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(T.rule, lineWidth: AppStroke.hairline)
        }
        .padding(.horizontal, T.pad)
    }

    private var signButton: some View {
        Button(action: onSign) {
            HStack(spacing: 9) {
                if isSigning {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.down.app.fill")
                }

                Text(isSigning ? "Signing…" : "Sign & Install")
                    .font(T.sans(16, .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [T.accent, T.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 0.8)
            }
            .shadow(color: T.accent.opacity(0.20), radius: 14, y: 7)
        }
        .buttonStyle(GlassTactileButtonStyle())
        .disabled(!canSign || isSigning)
        .opacity(canSign && !isSigning ? 1 : 0.48)
        .padding(.horizontal, T.pad)
    }
}
