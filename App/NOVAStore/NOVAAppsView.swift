import SwiftUI

struct NOVAAppsView: View {
    @Environment(\.forgeTheme) private var T
    @StateObject private var store = NOVAStoreService.shared
    @State private var search = ""
    @State private var selected: NOVAApp?

    private var filtered: [NOVAApp] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.apps }
        return store.apps.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            ($0.subtitle?.localizedCaseInsensitiveContains(q) ?? false) ||
            ($0.description?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("NOVA STORE")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(T.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(T.accent)
                        TextField("ابحث عن تطبيق أو لعبة", text: $search)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(12)
                    .background(T.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(T.accent.opacity(0.18))
                    }

                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { app in
                            Button { selected = app } label: {
                                appRow(app)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, T.pad)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(ForgeBackdrop())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh(force: true) }
            .task { await store.refresh() }
            .sheet(item: $selected) { app in
                NOVAAppDetailView(app: app)
            }
        }
    }

    private func appRow(_ app: NOVAApp) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: app.iconURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "app.fill")
                        .foregroundStyle(T.accent)
                }
            }
            .frame(width: 54, height: 54)
            .background(T.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(T.sans(15, .bold)).foregroundStyle(T.ink)
                if let subtitle = app.subtitle {
                    Text(subtitle).font(T.sans(11, .medium)).foregroundStyle(T.ink3).lineLimit(1)
                }
                if let version = app.version {
                    Text("v\(version)").font(T.mono(10)).foregroundStyle(T.ink4)
                }
            }

            Spacer()
            Image(systemName: "chevron.left").foregroundStyle(T.ink4)
        }
        .padding(12)
        .background(T.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(T.accent.opacity(0.12)) }
    }
}