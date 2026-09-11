import SwiftUI

/// الصفحة الرئيسية الجديدة لـ Zed Store.
/// حالياً هي واجهة أساسية فقط، ويمكن إضافة الأقسام والمزايا لاحقاً.
struct ZedHomeView: View {
    @Environment(\.forgeTheme) private var T
    @AppStorage("app.language") private var languageCode = AppLanguage.arabic.rawValue

    private var isArabic: Bool {
        languageCode == AppLanguage.arabic.rawValue
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ForgeBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        welcomeCard
                        emptyContentCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("iStoreIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: T.accent.opacity(0.22), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(isArabic ? "مرحباً بك" : "Welcome")
                    .font(T.sans(13, .medium))
                    .foregroundColor(T.ink2)

                Text("Zed Store")
                    .font(T.display(26))
                    .foregroundColor(T.accent)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(T.accent.opacity(0.10))
                    .frame(width: 150, height: 150)
                    .offset(x: 38, y: 45)

                Circle()
                    .fill(T.accentHi.opacity(0.08))
                    .frame(width: 90, height: 90)
                    .offset(x: -8, y: 22)

                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [T.accent, T.accentHi],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(isArabic ? "الرئيسية" : "Home")
                        .font(T.display(30))
                        .foregroundColor(T.ink)

                    Text(
                        isArabic
                        ? "هذه الصفحة مخصصة للمحتوى الرئيسي. سنبنيها خطوة بخطوة حسب الأشياء التي تريد إضافتها."
                        : "This page is reserved for the main content. We can build it step by step around the features you choose."
                    )
                    .font(T.sans(14, .regular))
                    .foregroundColor(T.ink2)
                    .lineSpacing(3)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.card, cornerRadius: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(T.accent.opacity(0.12), lineWidth: AppStroke.hairline)
        }
    }

    private var emptyContentCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(T.accent)

            Text(isArabic ? "مساحة جاهزة للتطوير" : "Ready to customize")
                .font(T.sans(17, .semibold))
                .foregroundColor(T.ink)

            Text(
                isArabic
                ? "لم أضع وظائف إضافية هنا حتى تقرر أنت ماذا تريد أن يظهر في الصفحة الرئيسية."
                : "No extra features are added yet, so you can decide what should appear on the Home page."
            )
            .font(T.sans(13.5, .regular))
            .foregroundColor(T.ink2)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .glassSurface(.card, cornerRadius: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(T.rule, lineWidth: AppStroke.hairline)
        }
    }
}
