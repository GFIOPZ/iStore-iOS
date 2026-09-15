import SwiftUI

struct NOVAAppDetailView: View {
    let app: NOVAApp

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // MARK: - Header
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
                                .foregroundStyle(.secondary)

                        case .empty:
                            ProgressView()

                        @unknown default:
                            Image(systemName: "app.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(28)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Text(app.name)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 14)

                // MARK: - Description
                if !app.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("الوصف")
                            .font(.headline)

                        Text(app.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                // MARK: - Version & Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("معلومات التطبيق")
                        .font(.headline)

                    infoRow(title: "الإصدار", value: app.version)
                    infoRow(title: "الحجم", value: app.size)
                }
                .padding(16)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // MARK: - Screenshots
                if !app.screenshots.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("صور التطبيق")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(app.screenshots.enumerated()), id: \.offset) { _, screenshot in
                                    AsyncImage(url: URL(string: screenshot)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()

                                        case .failure:
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.gray.opacity(0.15))
                                                .overlay {
                                                    Image(systemName: "photo")
                                                        .font(.title)
                                                        .foregroundStyle(.secondary)
                                                }

                                        case .empty:
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.gray.opacity(0.15))
                                                .overlay { ProgressView() }

                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(width: 220, height: 390)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                }

                // MARK: - Download
                if let downloadURL = URL(string: app.ipaURL),
                   !app.ipaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Link(destination: downloadURL) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("تحميل التطبيق")
                            Spacer()
                            Image(systemName: "chevron.left")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                } else {
                    Text("رابط التحميل غير متوفر حالياً")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
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
