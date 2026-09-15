import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.forgeTheme) private var T
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var auth: NOVAAuthService

    private let instagramURL = "https://www.instagram.com/nova_store_dz0?stkn=MWxtNTFucWt4aWlsdg=="
    private let telegramURL = "https://t.me/+PWSWZyfG6ww4NDY0"

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    headerCard
                    subscriptionCard
                    aboutStoreCard
                    socialCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .background { ForgeBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var headerCard: some View {
        VStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                T.accent.opacity(0.24),
                                T.accent.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 70
                        )
                    )
                    .frame(width: 130, height: 130)

                Image("NOVAStoreLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                    )
                    .shadow(
                        color: T.accent.opacity(0.22),
                        radius: 16,
                        y: 8
                    )
            }

            Text("NOVA STORE")
                .font(T.display(28, .bold))
                .foregroundStyle(T.ink)

            Text("حسابك واشتراكك في مكان واحد")
                .font(T.sans(13, .medium))
                .foregroundStyle(T.ink2)

            HStack(spacing: 7) {
                Circle()
                    .fill(T.good)
                    .frame(width: 7, height: 7)

                Text(auth.isLoggedIn ? "الحساب متصل" : "غير مسجل الدخول")
                    .font(T.sans(11.5, .semibold))
                    .foregroundStyle(
                        auth.isLoggedIn ? T.good : T.ink2
                    )
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                (auth.isLoggedIn ? T.good : T.ink2).opacity(0.10),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        (auth.isLoggedIn ? T.good : T.ink2).opacity(0.18),
                        lineWidth: 0.7
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .glassSurface(.hero, cornerRadius: 24)
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle(
                title: "باقتك الحالية",
                subtitle: "تفاصيل الاشتراك المسجل من لوحة التحكم",
                icon: "crown.fill"
            )

            VStack(spacing: 0) {
                infoRow(
                    icon: "person.crop.circle.fill",
                    title: "اسم المشترك",
                    value: displayName
                )

                rowDivider

                infoRow(
                    icon: "calendar.badge.plus",
                    title: "تاريخ التفعيل",
                    value: formatDate(auth.session?.activationAt)
                )

                rowDivider

                infoRow(
                    icon: "calendar.badge.clock",
                    title: "تاريخ الانتهاء",
                    value: formatDate(auth.session?.expiresAt)
                )
            }
            .padding(.horizontal, 14)
            .glassSurface(.listRow, cornerRadius: 18)

            statusRow
        }
        .cardSurface
    }

    private var displayName: String {
        if let value = auth.session?.displayName,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        if let value = auth.session?.username,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        return "غير متوفر"
    }

    private var statusRow: some View {
        let active = isSubscriptionActive

        return HStack(spacing: 8) {
            Image(
                systemName: active
                    ? "checkmark.seal.fill"
                    : "exclamationmark.triangle.fill"
            )
            .font(.system(size: 14, weight: .semibold))

            Text(
                active
                    ? "اشتراكك فعال حالياً"
                    : "الاشتراك غير فعال"
            )
            .font(T.sans(12.5, .semibold))

            Spacer()

            if let id = auth.session?.subscriptionID,
               !id.isEmpty {
                Text(id)
                    .font(T.mono(10.5, .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(active ? T.good : T.bad)
        .padding(.horizontal, 13)
        .frame(height: 40)
        .background(
            (active ? T.good : T.bad).opacity(0.08),
            in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }

    private var isSubscriptionActive: Bool {
        guard let date = parseDate(auth.session?.expiresAt) else {
            return false
        }

        return date > Date()
    }

    private var aboutStoreCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle(
                title: "حول NOVA STORE",
                subtitle: "كل ما تحتاجه بتجربة واحدة مرتبة وسريعة",
                icon: "sparkles"
            )

            Text("NOVA STORE")
                .font(T.display(19, .bold))
                .foregroundStyle(T.accent)

            Text(
                "واجهة حديثة لإدارة حسابك والوصول إلى التطبيقات والخدمات المتوفرة لك، مع تجربة استخدام بسيطة وسريعة وبتصميم احترافي."
            )
            .font(T.sans(13.5, .regular))
            .foregroundStyle(T.ink2)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                featureBadge(icon: "bolt.fill", text: "سريع")
                featureBadge(icon: "lock.fill", text: "موثوق")
                featureBadge(icon: "wand.and.stars", text: "احترافي")
            }
            .padding(.top, 2)
        }
        .cardSurface
    }

    private func featureBadge(
        icon: String,
        text: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))

            Text(text)
                .font(T.sans(10.5, .semibold))
        }
        .foregroundStyle(T.accent)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(T.accentSoft, in: Capsule())
    }

    private var socialCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle(
                title: "تابع NOVA STORE",
                subtitle: "آخر التحديثات والعروض تجدها هنا",
                icon: "megaphone.fill"
            )

            HStack(spacing: 10) {
                socialButton(
                    title: "Instagram",
                    subtitle: "حساب المتجر",
                    icon: "camera.fill",
                    url: instagramURL
                )

                socialButton(
                    title: "Telegram",
                    subtitle: "قناة التحديثات",
                    icon: "paperplane.fill",
                    url: telegramURL
                )
            }
        }
        .cardSurface
    }

    private func socialButton(
        title: String,
        subtitle: String,
        icon: String,
        url: String
    ) -> some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.prepare()
            haptic.impactOccurred()

            guard let destination = URL(string: url) else {
                return
            }

            openURL(destination)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(T.accent)

                Text(title)
                    .font(T.sans(12.5, .semibold))
                    .foregroundStyle(T.ink)

                Text(subtitle)
                    .font(T.sans(9.5, .medium))
                    .foregroundStyle(T.ink3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
            )
            .fClearGlass(
                in: RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                ),
                interactive: true,
                showRim: false,
                useRegularInteractiveGlass: true
            )
        }
        .buttonStyle(GlassTactileButtonStyle())
    }

    private func sectionTitle(
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(T.accent)
                .frame(width: 32, height: 32)
                .background(
                    T.accentSoft,
                    in: RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(T.sans(15.5, .bold))
                    .foregroundStyle(T.ink)

                Text(subtitle)
                    .font(T.sans(10.5, .medium))
                    .foregroundStyle(T.ink3)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    private func infoRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(T.accent)
                .frame(width: 30, height: 30)
                .background(
                    T.accentSoft,
                    in: RoundedRectangle(
                        cornerRadius: 9,
                        style: .continuous
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(T.sans(10.5, .medium))
                    .foregroundStyle(T.ink3)

                Text(value)
                    .font(T.sans(13, .semibold))
                    .foregroundStyle(T.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 58)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(T.rule.opacity(0.65))
            .frame(height: 0.6)
            .padding(.leading, 41)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func formatDate(_ value: String?) -> String {
        guard let date = parseDate(value) else {
            return "غير متوفر"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_IQ")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: date)
    }
}

private extension View {
    var cardSurface: some View {
        self
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .glassSurface(.card, cornerRadius: 22)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    Color.primary.opacity(0.10),
                    lineWidth: AppStroke.hairline
                )
            }
    }
}
