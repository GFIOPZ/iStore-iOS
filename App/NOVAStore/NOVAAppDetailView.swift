import SwiftUI

struct NOVAAppDetailView: View {
    let app: NOVAApp

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repositories: RepositoryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - App Header

                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: app.icon)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()

                        case .failure:
                            Image(systemName: "app.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(28)

                        case .empty:
                            ProgressView()

                        @unknown default:
                            Image(systemName: "app.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(28)
                        }
                    }
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Text(app.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    if !app.subtitle.isEmpty {
                        Text(app.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)

                // MARK: - App Information

                VStack(alignment: .leading, spacing: 12) {
                    Text("معلومات التطبيق")
                        .font(.headline)

                    infoRow(
                        title: "الإصدار",
                        value: app.version
                    )

                    infoRow(
                        title: "الحجم",
                        value: app.size
                    )

                    if !app.categoryID.isEmpty {
                        infoRow(
                            title: "التصنيف",
                            value: app.categoryID
                        )
                    }

                    if !app.sourceID.isEmpty {
                        infoRow(
                            title: "المصدر",
                            value: app.sourceID
                        )
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // MARK: - Description

                if !app.description.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("الوصف")
                            .font(.headline)

                        Text(app.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                // MARK: - Screenshots

                if !app.screenshots.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("صور التطبيق")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(
                                    Array(app.screenshots.enumerated()),
                                    id: \.offset
                                ) { _, screenshot in

                                    AsyncImage(
                                        url: URL(string: screenshot)
                                    ) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()

                                        case .failure:
                                            RoundedRectangle(
                                                cornerRadius: 16
                                            )
                                            .fill(.gray.opacity(0.15))
                                            .overlay {
                                                Image(
                                                    systemName: "photo"
                                                )
                                                .font(.title)
                                                .foregroundStyle(.secondary)
                                            }

                                        case .empty:
                                            RoundedRectangle(
                                                cornerRadius: 16
                                            )
                                            .fill(.gray.opacity(0.15))
                                            .overlay {
                                                ProgressView()
                                            }

                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(
                                        width: 220,
                                        height: 390
                                    )
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 16
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                // MARK: - Download

                if !app.ipaURL.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty,
                   let downloadURL = URL(
                    string: app.ipaURL
                   ) {

                    Link(destination: downloadURL) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")

                            Text("تحميل التطبيق")

                            Spacer()

                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            Color.accentColor
                        )
                        .foregroundStyle(.white)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16
                            )
                        )
                    }
                } else {
                    Text("رابط التحميل غير متوفر حالياً")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16
                            )
                        )
                }
            }
            .padding()
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Info Row

    @ViewBuilder
    private func infoRow(
        title: String,
        value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value.isEmpty ? "-" : value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}
