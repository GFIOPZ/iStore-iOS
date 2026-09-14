import SwiftUI

struct NOVAAutoRefresher: ViewModifier {
    @StateObject private var store = NOVAStoreService.shared
    @EnvironmentObject private var repositories: RepositoryStore
    
    // متغير لضمان عمل التحديث التلقائي مرة واحدة فقط عند الدخول
    @State private var hasAutoRefreshed = false

    func body(content: Content) -> some View {
        content
            .task {
                guard !hasAutoRefreshed else { return }
                hasAutoRefreshed = true
                
                // 1. تحديث بيانات المتجر الأساسية
                await store.refresh(force: true)
                
                // 2. تحديث جميع المصادر (Repositories) لجلب التطبيقات الخارجية
                await withTaskGroup(of: Void.self) { group in
                    for repo in repositories.repositories {
                        group.addTask { await repositories.refresh(repo) }
                    }
                }
            }
    }
}

// إضافة اختصار (Extension) لتسهيل استخدامه على أي واجهة
extension View {
    func enableNovaAutoRefresh() -> some View {
        self.modifier(NOVAAutoRefresher())
    }
}
