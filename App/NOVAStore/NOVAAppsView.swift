import SwiftUI

struct NOVAAppsView: View {
    
    @StateObject private var store = NOVAStoreService.shared
    @State private var searchText = ""
    @State private var selectedApp: NOVAApp?
    
    private var filteredApps: [NOVAApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if q.isEmpty {
            return store.apps
        }
        
        return store.apps.filter { app in
            app.name.localizedCaseInsensitiveContains(q) ||
            app.subtitle.localizedCaseInsensitiveContains(q) ||
            app.description.localizedCaseInsensitiveContains(q)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if store.isLoading && store.apps.isEmpty {
                    ProgressView("جاري تحميل التطبيقات...")
                    
                } else if let error = store.errorMessage,
                          store.apps.isEmpty {
                    
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 42))
                        
                        Text("تعذر تحميل التطبيقات")
                            .font(.headline)
                        
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            Task {
                                await store.refresh(force: true)
                            }
                        } label: {
                            Label("إعادة المحاولة", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    
                } else if filteredApps.isEmpty {
                    
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        
                        Text(
                            searchText.isEmpty
                            ? "لا توجد تطبيقات حالياً"
                            : "لا توجد نتائج"
                        )
                        .font(.headline)
                        
                        if !searchText.isEmpty {
                            Text("جرّب البحث باسم تطبيق آخر")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                } else {
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredApps) { app in
                                Button {
                                    selectedApp = app
                                } label: {
                                    appRow(app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await store.refresh(force: true)
                    }
                }
            }
            .navigationTitle("NOVA STORE")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(
                    displayMode: .automatic
                ),
                prompt: "ابحث عن تطبيق"
            )
            .task {
                await store.refresh()
            }
            .sheet(item: $selectedApp) { app in
                NOVAAppDetailView(app: app)
            }
        }
    }
    
    @ViewBuilder
    private func appRow(_ app: NOVAApp) -> some View {
        HStack(spacing: 14) {
            
            AsyncImage(url: URL(string: app.icon)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                    
                default:
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.12))
                        
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if !app.subtitle.isEmpty {
                    Text(app.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if !app.version.isEmpty {
                        Text("v\(app.version)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    
                    if !app.size.isEmpty {
                        Text(app.size)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    NOVAAppsView()
}
