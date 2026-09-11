import SwiftUI

struct NOVAAppDetailView: View {
    let app: NOVAApp

    @Environment(\.forgeTheme) private var T
    @EnvironmentObject private var repositories: RepositoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AsyncImage(url: app.iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(T.accent)
                        }
                    }
                    .frame(width: 92, height: 92)
                    .background(T.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Text(app.name)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(T.ink)

                    if let subtitle = app.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(T.sans(13, .medium))
                            .foregroundStyle(T.ink3)
                    }

                    HStack(spacing: 8) {
                        if let version = app.version {
                            infoPill("v\(version)")
                        }
                        if let size = app.size, !size.isEmpty {
                            infoPill(size)
                        }
                    }

                    if let description = app.description, !description.isEmpty {
                        Text(description)
                            .font(T.sans(14, .medium))
                            .foregroundStyle(T.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let url = app.downloadURL {
                        Link(destination: url) {
                            Label("تحميل التطبيق", systemImage: "arrow.down.circle.fill")
                                .font(T.sans(15, .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(T.accent, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    if let screenshots = app.screenshots, !screenshots.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Screenshots")
                                .font(T.sans(18, .bold))
                                .foregroundStyle(T.ink)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(screenshots, id: \.self) { raw in
                                        if let url = URL(string: raw) {
                                            AsyncImage(url: url) { phase in
                                                if case .success(let image) = phase {
                                                    image.resizable().scaledToFill()
                                                } else {
                                                    Rectangle().fill(T.accentSoft)
                                                }
                                            }
                                            .frame(width: 180, height: 320)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(ForgeBackdrop())
            .navigationTitle("NOVA STORE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("تم") { dismiss() }
                }
            }
        }
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(T.mono(10, .bold))
            .foregroundStyle(T.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(T.accentSoft, in: Capsule())
    }
}