import SwiftUI

struct NOVACertificatePasswordSheet: View {
    @Binding var password: String
    let onCancel: () -> Void
    let onImport: () -> Void

    @Environment(\.forgeTheme) private var T
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(T.accent.opacity(0.12))
                        .frame(width: 58, height: 58)

                    Image(systemName: "key.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(T.accent)
                }

                VStack(spacing: 6) {
                    Text("رمز الشهادة")
                        .font(T.sans(19, .bold))
                        .foregroundStyle(T.ink)

                    Text("اكتب رمز ملف P12. إذا تركته كما هو سيتم استخدام الرمز 1.")
                        .font(T.sans(11.5, .medium))
                        .foregroundStyle(T.ink3)
                        .multilineTextAlignment(.center)
                }

                SecureField("رمز P12", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.horizontal, 15)
                    .frame(height: 52)
                    .background(
                        T.surface3,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(T.accent.opacity(0.20), lineWidth: AppStroke.hairline)
                    }

                HStack(spacing: 10) {
                    Button("إلغاء") {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(T.ink)
                    .glassSurface(.button, cornerRadius: 15)

                    Button("استيراد") {
                        onImport()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(T.accent)
                    .glassSurface(.button, cornerRadius: 15)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(T.accent.opacity(0.24), lineWidth: AppStroke.hairline)
                    }
                }
            }
            .padding(22)
            .background { ForgeBackdrop().ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    focused = true
                }
            }
        }
    }
}

struct NOVACertificateInfoSheet: View {
    let certificate: CertificateRecord
    let profile: ProfileRecord?
    let languageCode: String

    @Environment(\.forgeTheme) private var T

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header

                    infoCard(
                        icon: "person.text.rectangle.fill",
                        title: "اسم الشهادة",
                        value: certificate.displayName
                    )

                    if let commonName = certificate.commonName,
                       !commonName.isEmpty,
                       commonName != certificate.displayName {
                        infoCard(
                            icon: "person.crop.rectangle.fill",
                            title: "Common Name",
                            value: commonName
                        )
                    }

                    if let organization = certificate.organization,
                       !organization.isEmpty {
                        infoCard(
                            icon: "building.2.fill",
                            title: "الجهة",
                            value: organization
                        )
                    }

                    if let teamID = certificate.teamID,
                       !teamID.isEmpty {
                        infoCard(
                            icon: "person.3.fill",
                            title: "Team ID",
                            value: teamID
                        )
                    }

                    infoCard(
                        icon: "calendar.badge.clock",
                        title: "تاريخ الانتهاء",
                        value: formattedDate(certificate.notAfter)
                    )

                    infoCard(
                        icon: "hourglass",
                        title: "المدة المتبقية",
                        value: remainingText(certificate.notAfter)
                    )

                    if let profile {
                        infoCard(
                            icon: "checkmark.seal.fill",
                            title: "البروفايل",
                            value: profile.displayName
                        )

                        if let appID = profile.applicationIdentifier,
                           !appID.isEmpty {
                            infoCard(
                                icon: "app.badge.fill",
                                title: "App ID",
                                value: appID
                            )
                        }

                        if let teamID = profile.teamID,
                           !teamID.isEmpty {
                            infoCard(
                                icon: "person.3.fill",
                                title: "Profile Team ID",
                                value: teamID
                            )
                        }

                        infoCard(
                            icon: "calendar",
                            title: "انتهاء البروفايل",
                            value: formattedDate(profile.notAfter)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 35)
            }
            .background { ForgeBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("تم") {}
                        .foregroundStyle(T.accent)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(T.accent.opacity(0.10))
                    .frame(width: 92, height: 92)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(T.accent)
            }

            Text("معلومات الشهادة")
                .font(T.sans(22, .bold))
                .foregroundStyle(T.ink)

            Text(certificate.filename)
                .font(T.mono(10.5, .medium))
                .foregroundStyle(T.ink3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func infoCard(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(T.accent)
                .frame(width: 40, height: 40)
                .background(
                    T.accent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(T.sans(10.5, .medium))
                    .foregroundStyle(T.ink3)

                Text(value)
                    .font(T.sans(13.5, .semibold))
                    .foregroundStyle(T.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.card, cornerRadius: 18)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(T.rule, lineWidth: AppStroke.hairline)
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "غير متوفر"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_IQ")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func remainingText(_ date: Date?) -> String {
        guard let date else {
            return "غير متوفر"
        }

        let days = Int(ceil(date.timeIntervalSinceNow / 86_400))

        if days <= 0 {
            return "منتهية"
        }

        if days == 1 {
            return "متبقي يوم واحد"
        }

        if days < 30 {
            return "متبقي \(days) يوم"
        }

        let months = days / 30

        if months < 12 {
            return "متبقي \(months) شهر"
        }

        let years = months / 12
        let remainingMonths = months % 12

        if remainingMonths == 0 {
            return "متبقي \(years) سنة"
        }

        return "متبقي \(years) سنة و\(remainingMonths) شهر"
    }
}
