import SwiftUI
import UIKit

struct NOVAAppsView: View {

    @StateObject private var store = NOVAStoreService.shared
    @State private var searchText = ""
    @State private var selectedApp: NOVAApp?
    @State private var isRefreshing = false

    // MARK: - Palette

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var filteredApps: [NOVAApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.apps }
        return store.apps.filter { app in
            app.name.localizedCaseInsensitiveContains(q) ||
            app.subtitle.localizedCaseInsensitiveContains(q) ||
            app.description.localizedCaseInsensitiveContains(q)
        }
    }

    private var isLoadingInitially: Bool { store.isLoading && store.apps.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoadingInitially {
                    ProgressView("جاري تحميل التطبيقات...")
                        .tint(gradientStart)

                } else if store.apps.isEmpty {
                    emptyState(
                        icon: "square.grid.2x2",
                        title: "لا توجد تطبيقات حالياً",
                        message: "قم بإضافة تطبيقات من لوحة التحكم لتظهر هنا."
                    )

                } else if filteredApps.isEmpty {
                    emptyState(
                        icon: "magnifyingglass",
                        title: "لا توجد نتائج",
                        message: "جرّب البحث باسم تطبيق آخر."
                    )

                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredApps) { app in
                                appRow(app)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 20)
                    }
                    .refreshable { await refreshAll() }
                }
            }
            .navigationTitle("NOVA STORE")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "ابحث عن تطبيق"
            )
            .task { if store.apps.isEmpty { await refreshAll() } }
            .sheet(item: $selectedApp) { app in
                NOVAAppDetailView(app: app)
            }
        }
        .tint(gradientStart)
    }

    private func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await store.refresh(force: true)
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(brandGradient.opacity(0.14))
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(brandGradient)
            }
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Row

    @ViewBuilder
    private func appRow(_ app: NOVAApp) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                selectedApp = app
            } label: {
                HStack(spacing: 12) {
                    CachedAppIcon(url: URL(string: app.icon), size: 54, cornerRadius: 14)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(brandGradient.opacity(0.35), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if !app.version.isEmpty {
                                Text("v\(app.version)")
                            }
                            if !app.size.isEmpty {
                                Text("•")
                                Text(app.size)
                            }
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Spacer(minLength: 4)

            installPill(app)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thickMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(brandGradient.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: gradientStart.opacity(0.08), radius: 10, y: 4)
    }

    @ViewBuilder
    private func installPill(_ app: NOVAApp) -> some View {
        let urlString = app.ipaURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: urlString), !urlString.isEmpty {
            Link(destination: url) {
                Text("تثبيت")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 34)
                    .background(brandGradient)
                    .clipShape(Capsule())
                    .shadow(color: gradientStart.opacity(0.35), radius: 6, y: 3)
            }
            .buttonStyle(PressableStyle())
        } else {
            Text("غير متوفر")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 78, height: 34)
                .background(Color.gray.opacity(0.4))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Press animation

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

private enum Haptics {
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

#Preview {
    NOVAAppsView()
}
