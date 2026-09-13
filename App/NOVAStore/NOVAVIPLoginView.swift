import SwiftUI

struct NOVAVIPLoginView: View {

    @EnvironmentObject
    private var auth: NOVAAuthService

    @State private var username = ""
    @State private var password = ""
    @State private var code = ""

    @State private var showPassword = false
    @State private var isLoading = false

    @State private var errorMessage: String?

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color.purple.opacity(0.95),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {

                VStack(spacing: 24) {

                    Spacer(minLength: 50)

                    VStack(spacing: 10) {

                        Image(
                            systemName:
                                "lock.shield.fill"
                        )
                        .font(.system(size: 55))
                        .foregroundStyle(.white)

                        Text("NOVA STORE")
                            .font(
                                .system(
                                    size: 32,
                                    weight: .black
                                )
                            )
                            .foregroundStyle(.white)

                        Text("منطقة المشتركين")
                            .font(.headline)
                            .foregroundStyle(
                                .white.opacity(0.75)
                            )
                    }

                    VStack(spacing: 16) {

                        novaField(
                            title: "اسم المستخدم",
                            icon: "person.fill",
                            text: $username
                        )

                        passwordField()

                        novaField(
                            title: "كود الاشتراك",
                            icon: "key.fill",
                            text: $code
                        )

                        if let errorMessage {

                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(
                                    .center
                                )
                                .padding(.horizontal)
                        }

                        Button {

                            Task {
                                await performLogin()
                            }

                        } label: {

                            HStack {

                                if isLoading {

                                    ProgressView()
                                        .tint(.white)

                                } else {

                                    Image(
                                        systemName:
                                            "arrow.right.circle.fill"
                                    )

                                    Text("تسجيل الدخول")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(
                                maxWidth: .infinity
                            )
                            .frame(height: 54)
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                        .tint(.purple)
                        .disabled(isLoading)
                    }
                    .padding(22)
                    .background(
                        .ultraThinMaterial,
                        in:
                            RoundedRectangle(
                                cornerRadius: 28
                            )
                    )

                    Text(
                        "NOVA STORE • Secure Access"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .white.opacity(0.45)
                    )

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
            }
        }
    }


    // MARK: - Normal Field

    private func novaField(
        title: String,
        icon: String,
        text: Binding<String>
    ) -> some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .foregroundStyle(.purple)

            TextField(
                title,
                text: text
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding()
        .background(
            Color.white.opacity(0.95),
            in:
                RoundedRectangle(
                    cornerRadius: 16
                )
        )
    }


    // MARK: - Password

    private func passwordField() -> some View {

        HStack(spacing: 12) {

            Image(
                systemName:
                    "lock.fill"
            )
            .foregroundStyle(.purple)

            Group {

                if showPassword {

                    TextField(
                        "كلمة المرور",
                        text: $password
                    )

                } else {

                    SecureField(
                        "كلمة المرور",
                        text: $password
                    )
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {

                showPassword.toggle()

            } label: {

                Image(
                    systemName:
                        showPassword
                        ? "eye.slash.fill"
                        : "eye.fill"
                )
                .foregroundStyle(.purple)
            }
        }
        .padding()
        .background(
            Color.white.opacity(0.95),
            in:
                RoundedRectangle(
                    cornerRadius: 16
                )
        )
    }


    // MARK: - Login

    private func performLogin() async {

        errorMessage = nil

        guard !username.isEmpty else {
            errorMessage =
                "اكتب اسم المستخدم."
            return
        }

        guard !password.isEmpty else {
            errorMessage =
                "اكتب كلمة المرور."
            return
        }

        guard !code.isEmpty else {
            errorMessage =
                "اكتب كود الاشتراك."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {

            try await auth.login(
                username: username,
                password: password,
                code: code
            )

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }
}
