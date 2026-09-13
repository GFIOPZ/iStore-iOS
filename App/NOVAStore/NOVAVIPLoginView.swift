import SwiftUI
import UIKit

struct NOVAVIPLoginView: View {
    @EnvironmentObject private var auth: NOVAAuthService

    @State private var username = ""
    @State private var password = ""
    @State private var activationCode = ""

    @State private var focusedField: Field?
    @State private var appeared = false
    @State private var isLoggingIn = false
    @State private var showPassword = false

    enum Field {
        case username
        case password
        case code
    }

    var body: some View {
        ZStack {
            premiumBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    Spacer(minLength: 55)

                    header
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 25)

                    Spacer(minLength: 34)

                    loginCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 35)

                    Spacer(minLength: 28)

                    footer
                        .opacity(appeared ? 1 : 0)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(
                .spring(
                    response: 0.7,
                    dampingFraction: 0.82
                )
            ) {
                appeared = true
            }
        }
        .alert(
            "تعذر تسجيل الدخول",
            isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { if !$0 { auth.errorMessage = nil } }
            )
        ) {
            Button("حسناً", role: .cancel) {
                auth.errorMessage = nil
            }
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }

    // MARK: - Background

    private var premiumBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "07050D"),
                    Color(hex: "0D0819"),
                    Color(hex: "120B24"),
                    Color(hex: "07050D")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "7C3AED").opacity(0.18))
                .frame(width: 330, height: 330)
                .blur(radius: 90)
                .offset(x: -150, y: -300)

            Circle()
                .fill(Color(hex: "A855F7").opacity(0.13))
                .frame(width: 280, height: 280)
                .blur(radius: 85)
                .offset(x: 170, y: 250)

            Circle()
                .stroke(
                    Color.white.opacity(0.035),
                    lineWidth: 1
                )
                .frame(width: 420, height: 420)
                .offset(x: 160, y: -250)

            Circle()
                .stroke(
                    Color.white.opacity(0.025),
                    lineWidth: 1
                )
                .frame(width: 600, height: 600)
                .offset(x: -180, y: 300)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 18) {

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "A855F7").opacity(0.25),
                                Color(hex: "7C3AED").opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 108, height: 108)
                    .blur(radius: 1)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 108, height: 108)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "F5D77A"),
                                Color(hex: "C9962E")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: Color(hex: "F5D77A").opacity(0.3),
                        radius: 18
                    )
            }

            VStack(spacing: 7) {
                Text("NOVA")
                    .font(
                        .system(
                            size: 34,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .tracking(1.8)
                    .foregroundStyle(.white)

                Text("VIP")
                    .font(
                        .system(
                            size: 18,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .tracking(5)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "C084FC"),
                                Color(hex: "8B5CF6")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Text("دخول آمن إلى تجربة NOVA STORE")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.52))
        }
    }

    // MARK: - Card

    private var loginCard: some View {
        VStack(spacing: 22) {

            VStack(alignment: .leading, spacing: 6) {
                Text("تسجيل الدخول")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)

                Text("أدخل بيانات اشتراكك للمتابعة")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {

                premiumField(
                    icon: "person",
                    title: "اسم المستخدم",
                    placeholder: "أدخل اسم المستخدم",
                    text: $username,
                    field: .username
                )

                passwordField

                premiumField(
                    icon: "key",
                    title: "كود التفعيل",
                    placeholder: "XXXX-XXXX-XXXX",
                    text: $activationCode,
                    field: .code
                )
            }

            if let error = auth.errorMessage, !error.isEmpty {
                errorBanner(error)
            }

            loginButton
        }
        .padding(22)
        .background(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
        .shadow(
            color: .black.opacity(0.35),
            radius: 35,
            x: 0,
            y: 20
        )
    }

    // MARK: - Password

    private var passwordField: some View {
        HStack(spacing: 13) {

            Image(systemName: "lock")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    focusedField == .password
                    ? Color(hex: "A855F7")
                    : Color.white.opacity(0.42)
                )
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text("كلمة المرور")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.38))

                Group {
                    if showPassword {
                        TextField("أدخل كلمة المرور", text: $password)
                    } else {
                        SecureField("أدخل كلمة المرور", text: $password)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(
                    Binding(
                        get: { focusedField == .password },
                        set: { focusedField = $0 ? .password : nil }
                    )
                )
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(
                    systemName: showPassword
                    ? "eye.slash"
                    : "eye"
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 67)
        .background(fieldBackground(.password))
    }

    // MARK: - Field

    private func premiumField(
        icon: String,
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {

        HStack(spacing: 13) {

            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    focusedField == field
                    ? Color(hex: "A855F7")
                    : Color.white.opacity(0.42)
                )
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.38))

                TextField(placeholder, text: text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(
                        Binding(
                            get: { focusedField == field },
                            set: {
                                focusedField = $0 ? field : nil
                            }
                        )
                    )
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 67)
        .background(fieldBackground(field))
    }

    private func fieldBackground(_ field: Field) -> some View {
        RoundedRectangle(
            cornerRadius: 18,
            style: .continuous
        )
        .fill(Color.black.opacity(0.20))
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                focusedField == field
                ? Color(hex: "A855F7").opacity(0.65)
                : Color.white.opacity(0.075),
                lineWidth: focusedField == field ? 1.2 : 1
            )
        )
    }

    // MARK: - Login Button

    private var loginButton: some View {
        Button {
            login()
        } label: {
            ZStack {

                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "7C3AED"),
                            Color(hex: "A855F7")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.18),
                    lineWidth: 1
                )

                if isLoggingIn {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    HStack(spacing: 10) {
                        Text("متابعة")
                            .font(.system(size: 16, weight: .bold))

                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(height: 58)
            .shadow(
                color: Color(hex: "8B5CF6").opacity(0.32),
                radius: 20,
                x: 0,
                y: 10
            )
        }
        .buttonStyle(.plain)
        .disabled(
            isLoggingIn ||
            username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            password.isEmpty ||
            activationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .opacity(
            username.isEmpty ||
            password.isEmpty ||
            activationCode.isEmpty
            ? 0.55
            : 1
        )
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.orange)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                Color.orange.opacity(0.16),
                lineWidth: 1
            )
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 11))

            Text("اتصال محمي • NOVA STORE VIP")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.white.opacity(0.28))
    }

    // MARK: - Login

    private func login() {
        guard !isLoggingIn else { return }

        isLoggingIn = true
        focusedField = nil

        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred()

        Task {
            do {
                try await auth.login(
                    username: username.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    password: password,
                    code: activationCode.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )

                await MainActor.run {
                    UINotificationFeedbackGenerator()
                        .notificationOccurred(.success)

                    isLoggingIn = false
                }
            } catch {
                await MainActor.run {
                    isLoggingIn = false
                }
            }
        }
    }
}
