import SwiftUI
import UIKit
import AudioToolbox

/// "التطبيقات" tab — modern NOVA STORE catalog with a compact card layout,
/// persistent search, exclusive-apps mode, wave/parallax scrolling and a
/// polished install state.
struct NOVAAppsView: View {

    @EnvironmentObject private var store: RepositoryStore
    @StateObject private var manualApps = NOVAStoreService.shared
    @State private var searchText = ""
    @State private var selectedApp: RepoApp?
    @State private var isRefreshing = false
    @State private var showExclusiveApps = false

    // The hint is shown once per app launch, not every time the user changes tabs.
    @SceneStorage("nova.apps.exclusiveHintShown") private var hasShownExclusiveHint = false
    @State private var showExclusiveHint = false

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sourceApps: [RepoApp] {
        var seen = Set<String>()
        var result: [RepoApp] = []

        for repo in store.repositories {
            guard let apps = store.catalog[repo.id]?.apps else { continue }
            for app in apps where seen.insert(app.id).inserted {
                result.append(app)
            }
        }

        return result
    }

    private var exclusiveApps: [RepoApp] {
        var seen = Set<String>()
        return manualApps.apps
            .filter { $0.enabled && $0.showInApps && $0.exclusive }
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.updatedAt > $1.updatedAt
            }
            .map(RepoApp.init(novaApp:))
            .filter { seen.insert($0.id).inserted }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    /// Normal mode contains source apps plus the manually curated NOVA apps.
    /// Duplicate bundle IDs are kept only once.
    private var allApps: [RepoApp] {
        var seen = Set<String>()
        var result: [RepoApp] = []

        for app in sourceApps where seen.insert(app.id).inserted {
            result.append(app)
        }

        for app in manualApps.apps
            .filter({ $0.enabled && $0.showInApps })
            .sorted(by: {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.updatedAt > $1.updatedAt
            })
            .map(RepoApp.init(novaApp:))
            where seen.insert(app.id).inserted {
            result.append(app)
        }

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var baseApps: [RepoApp] {
        showExclusiveApps ? exclusiveApps : allApps
    }

    private var filteredApps: [RepoApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return baseApps }

        return baseApps.filter { app in
            app.name.localizedCaseInsensitiveContains(q) ||
            (app.developerName?.localizedCaseInsensitiveContains(q) ?? false) ||
            (app.localizedDescription?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var hasAnyApps: Bool {
        !allApps.isEmpty
    }

    private var isLoadingInitially: Bool {
        isRefreshing && !hasAnyApps
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                ForgeBackdrop()
                    .ignoresSafeArea()

                if isLoadingInitially {
                    ProgressView("جاري تحميل التطبيقات...")
                        .tint(gradientStart)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if !hasAnyApps {
                    emptyState(
                        icon: "shippingbox",
                        title: "لا توجد تطبيقات حالياً",
                        message: "اسحب للأسفل لتحديث المصادر."
                    )

                } else if filteredApps.isEmpty {
                    emptyState(
                        icon: "magnifyingglass",
                        title: "لا توجد نتائج",
                        message: "جرّب البحث باسم تطبيق آخر."
                    )

                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredApps) { app in
                                waveRow(app)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, showExclusiveHint ? 177 : 126)
                        .padding(.bottom, 30)
                    }
                    .coordinateSpace(name: "NOVAAppsScroll")
                    .refreshable { await refreshAll() }
                }

                header
            }
            .navigationBarHidden(true)
            .task {
                if manualApps.apps.isEmpty {
                    await manualApps.refresh()
                }
                if allApps.isEmpty {
                    await refreshAll()
                }
            }
            .onAppear {
                showExclusiveHintOnce()
            }
            .sheet(item: $selectedApp) { app in
                RepoAppDetailSheet(app: app)
            }
        }
        .tint(gradientStart)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NOVA STORE")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(brandGradient)
                        .tracking(-0.8)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(gradientEnd)
                            .frame(width: 6, height: 6)

                        Text(showExclusiveApps ? "الحصريات • \(exclusiveApps.count) تطبيق" : "\(allApps.count) تطبيق")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topTrailing)

                exclusiveButton
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 20)
            .padding(.top, 13)
            .padding(.bottom, 9)

            searchBar

            if showExclusiveHint {
                ExclusiveHintBubble()
                    .padding(.top, 1)
                    .padding(.horizontal, 18)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    .zIndex(30)
            }
        }
        .background {
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0.96),
                    Color(.systemBackground).opacity(0.72),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(gradientStart.opacity(0.78))

            TextField("ابحث عن تطبيق", text: $searchText)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(gradientStart.opacity(0.13), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 9)
    }

    private var exclusiveButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                showExclusiveApps.toggle()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(gradientStart.opacity(0.20), lineWidth: 1)

                if showExclusiveApps {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .bold))

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .background(Circle().fill(.ultraThinMaterial))
                            .offset(x: 4, y: 4)
                    }
                    .foregroundStyle(brandGradient)
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(brandGradient)
                }
            }
            .frame(width: 52, height: 52)
            .shadow(color: gradientStart.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Wave rows

    private func waveRow(_ app: RepoApp) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("NOVAAppsScroll"))
            let viewportCenter = UIScreen.main.bounds.height * 0.48
            let distance = abs(frame.midY - viewportCenter)
            let amount = min(distance / 700, 1)
            let wave = sin(frame.midY / 105) * (1 - amount) * 5
            let lift = sin(frame.midY / 125) * (1 - amount) * 1.5

            appRow(app)
                .scaleEffect(0.985 + (1 - amount) * 0.015)
                .offset(x: wave, y: lift)
                .opacity(0.92 + (1 - amount) * 0.08)
        }
        .frame(height: 88)
    }

    @ViewBuilder
    private func appRow(_ app: RepoApp) -> some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                selectedApp = app
            } label: {
                HStack(spacing: 10) {
                    CachedAppIcon(url: app.iconURL, size: 46, cornerRadius: 12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(brandGradient.opacity(0.25), lineWidth: 0.8)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            if let version = app.version, !version.isEmpty {
                                Text("v\(version)")
                            }
                            if let size = app.size {
                                Text("•")
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            }
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                        if let dev = app.developerName, !dev.isEmpty {
                            Text(dev)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Spacer(minLength: 3)

            installPill(app)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(gradientStart.opacity(0.13), lineWidth: 0.9)
        }
        .shadow(color: gradientStart.opacity(0.055), radius: 8, y: 3)
    }

    @ViewBuilder
    private func installPill(_ app: RepoApp) -> some View {
        if store.activeDownloadID == app.id {
            InstallActivityView()
                .frame(width: 76, height: 34)
                .background(brandGradient)
                .clipShape(Capsule())
                .shadow(color: gradientStart.opacity(0.25), radius: 7, y: 3)
        } else {
            Button {
                Haptics.installSoundAndImpact()
                Task { await store.download(app) }
            } label: {
                Text("تثبيت")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 34)
                    .background(
                        app.downloadURL == nil
                            ? AnyShapeStyle(Color.gray.opacity(0.38))
                            : AnyShapeStyle(brandGradient)
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: gradientStart.opacity(app.downloadURL == nil ? 0 : 0.28),
                        radius: 6,
                        y: 3
                    )
            }
            .buttonStyle(PressableStyle())
            .disabled(app.downloadURL == nil || store.activeDownloadID != nil)
        }
    }

    // MARK: - Data

    private func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await manualApps.refresh()

        await withTaskGroup(of: Void.self) { group in
            for repo in store.repositories {
                group.addTask { await store.refresh(repo) }
            }
        }
    }

    private func showExclusiveHintOnce() {
        guard !hasShownExclusiveHint else { return }
        hasShownExclusiveHint = true

        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            showExclusiveHint = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                showExclusiveHint = false
            }
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(brandGradient.opacity(0.13))
                    .frame(width: 78, height: 78)

                Image(systemName: icon)
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(brandGradient)
            }

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Exclusive hint

private struct ExclusiveHintBubble: View {
    private let purple = Color(hex: "7C3AED")

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("اضغط هنا وشاهد حصرياتكم 🔥")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("تطبيقات مضافة من لوحة التحكم")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(purple)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(purple.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: purple.opacity(0.14), radius: 12, y: 5)
    }
}

// MARK: - Install animation

private struct InstallActivityView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 14, weight: .bold))
                .rotationEffect(.degrees(animate ? 9 : -9))
                .scaleEffect(animate ? 1.08 : 0.94)

            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: 2.5, height: animate ? CGFloat(7 + index * 3) : CGFloat(15 - index * 2))
                }
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.52)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// MARK: - Interaction

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.62),
                value: configuration.isPressed
            )
    }
}

@MainActor
private enum Haptics {
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func installSoundAndImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        AudioServicesPlaySystemSound(1407)
    }
}

#Preview {
    NOVAAppsView()
        .environmentObject(RepositoryStore())
}
