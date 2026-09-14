import SwiftUI
import UniformTypeIdentifiers

struct ImportApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var T

    @State private var showIPAImporter = false
    @State private var showURLImporter = false

    @Binding var importURLText: String
    let isDownloadingURL: Bool
    let onImportURL: () -> Void

    let ipaURL: URL?
    let appName: String
    let bundleID: String
    let preflightState: IPAPreflightState
    let importedURLs: [URL]
    let onIPA: (URL) -> Void
    let onOpenApp: (URL) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    sourceChoices
                    yourApps
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { ForgeBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showIPAImporter) {
                ForgeDocumentPicker { urls in
                    showIPAImporter = false
                    guard let url = urls.first else { return }
                    let ext = url.pathExtension.lowercased()
                    guard ext == "ipa" || ext == "zip" else { return }
                    onIPA(url)
                } onCancel: {
                    showIPAImporter = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showURLImporter) {
                URLImportSheet(
                    urlText: $importURLText,
                    isLoading: isDownloadingURL,
                    importAction: onImportURL
                )
            }
        }
        .floatingGlassBackButton(action: { dismiss() })
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(T.accent.opacity(0.10))
                    .frame(width: 72, height: 72)

                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(T.accent)
                    .frame(width: 56, height: 56)
                    .glassSurface(.icon, cornerRadius: 19)
            }

            Text("Import Application")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(T.ink)

            Text("Choose how you want to add your application")
                .font(T.sans(11, .medium))
                .foregroundStyle(T.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var sourceChoices: some View {
        HStack(spacing: 12) {
            sourceCard(title: "IPA", subtitle: "From Files", icon: "folder.fill", primary: true) {
                showIPAImporter = true
            }

            sourceCard(title: "Link", subtitle: "From URL", icon: "link", primary: false) {
                showURLImporter = true
            }
        }
        .padding(.horizontal, T.pad)
        .padding(.top, 28)
    }

    private func sourceCard(
        title: String,
        subtitle: String,
        icon: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(primary ? T.accent : T.ink)
                    .frame(width: 42, height: 42)
                    .glassSurface(.icon, cornerRadius: 14)

                Text(title)
                    .font(T.sans(15, .bold))
                    .foregroundStyle(T.ink)

                Text(subtitle)
                    .font(T.mono(8, .medium))
                    .foregroundStyle(T.ink3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 126)
            .glassSurface(primary ? .button : .card, cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(primary ? T.accent.opacity(0.20) : T.rule, lineWidth: AppStroke.hairline)
            }
        }
        .buttonStyle(GlassTactileButtonStyle())
    }

    private var yourApps: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Applications")
                        .font(T.sans(16, .bold))
                        .foregroundStyle(T.ink)

                    Text("Imported apps ready to sign")
                        .font(T.mono(8, .medium))
                        .foregroundStyle(T.ink3)
                }

                Spacer()

                Text("\(importedURLs.count)")
                    .font(T.mono(10, .bold))
                    .foregroundStyle(T.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassSurface(.badge, cornerRadius: 999)
            }

            if importedURLs.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(T.accent.opacity(0.75))

                    Text("No applications yet")
                        .font(T.sans(13, .semibold))
                        .foregroundStyle(T.ink2)

                    Text("Import an IPA from Files or use a link above.")
                        .font(T.mono(8, .medium))
                        .foregroundStyle(T.ink3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .glassSurface(.card, cornerRadius: 20)
            } else {
                VStack(spacing: 9) {
                    ForEach(importedURLs, id: \.path) { url in
                        importedApplicationCard(url: url, isActive: url.path == ipaURL?.path)
                    }
                }
            }
        }
        .padding(.horizontal, T.pad)
        .padding(.top, 30)
    }

    private func importedApplicationCard(url: URL, isActive: Bool) -> some View {
        Button(action: { onOpenApp(url) }) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(isActive ? T.accent.opacity(0.12) : T.surface3)
                        .frame(width: 56, height: 56)

                    Image(systemName: "app.fill")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(isActive ? T.accent : T.ink2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isActive && !appName.isEmpty
                         ? appName
                         : url.deletingPathExtension().lastPathComponent)
                        .font(T.sans(15, .bold))
                        .foregroundStyle(T.ink)
                        .lineLimit(1)

                    if isActive, case .ready(let inspection) = preflightState {
                        Text(inspection.bundleIdentifier)
                            .font(T.mono(8, .medium))
                            .foregroundStyle(T.ink3)
                            .lineLimit(1)
                    } else if isActive, case .inspecting = preflightState {
                        Text("Reading app details…")
                            .font(T.mono(8, .medium))
                            .foregroundStyle(T.ink3)
                    } else {
                        Text(isActive ? (bundleID.isEmpty ? "Ready to sign" : bundleID) : "Tap to open")
                            .font(T.mono(8, .medium))
                            .foregroundStyle(T.ink3)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 5)

                Image(systemName: isActive ? "checkmark" : "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? T.accent : T.ink3)
                    .frame(width: 32, height: 32)
                    .glassSurface(.icon, cornerRadius: 12)
            }
            .padding(.horizontal, 14)
            .frame(height: 78)
            .glassSurface(isActive ? .button : .card, cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isActive ? T.accent.opacity(0.20) : T.rule, lineWidth: AppStroke.hairline)
            }
        }
        .buttonStyle(GlassTactileButtonStyle())
    }
}
