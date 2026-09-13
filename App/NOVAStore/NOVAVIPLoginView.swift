import SwiftUI


struct NOVAVIPLoginView: View {

    @EnvironmentObject
    private var auth:
        NOVAAuthService


    @State
    private var username = ""


    @State
    private var password = ""


    @State
    private var code = ""


    @State
    private var showPassword =
        false


    @State
    private var isLoading =
        false


    @State
    private var errorMessage:
        String?


    @State
    private var appear =
        false


    @State
    private var glow =
        false


    var body:
        some View {

        ZStack {

            background


            ScrollView(
                showsIndicators:
                    false
            ) {

                VStack(
                    spacing:
                        0
                ) {

                    Spacer(
                        minLength:
                            50
                    )


                    logo


                    Spacer(
                        minLength:
                            34
                    )


                    loginCard


                    Spacer(
                        minLength:
                            28
                    )


                    footer
                }

                .padding(
                    .horizontal,
                    22
                )
            }
        }

        .onAppear {

            withAnimation(
                .easeOut(
                    duration:
                        0.8
                )
            ) {

                appear =
                    true
            }


            withAnimation(
                .easeInOut(
                    duration:
                        2.0
                )
                .repeatForever(
                    autoreverses:
                        true
                )
            ) {

                glow =
                    true
            }
        }
    }


    // MARK: Background

    private var background:
        some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(
                        red:
                            0.035,
                        green:
                            0.015,
                        blue:
                            0.07
                    ),

                    Color(
                        red:
                            0.10,
                        green:
                            0.025,
                        blue:
                            0.17
                    ),

                    Color.black
                ],

                startPoint:
                    .topLeading,

                endPoint:
                    .bottomTrailing
            )


            Circle()

                .fill(
                    Color.purple
                        .opacity(
                            0.20
                        )
                )

                .frame(
                    width:
                        300,
                    height:
                        300
                )

                .blur(
                    radius:
                        70
                )

                .offset(
                    x:
                        -120,
                    y:
                        -260
                )


            Circle()

                .fill(
                    Color(
                        red:
                            0.55,
                        green:
                            0.15,
                        blue:
                            0.95
                    )
                    .opacity(
                        0.15
                    )
                )

                .frame(
                    width:
                        280,
                    height:
                        280
                )

                .blur(
                    radius:
                        80
                )

                .offset(
                    x:
                        150,
                    y:
                        250
                )
        }

        .ignoresSafeArea()
    }


    // MARK: Logo

    private var logo:
        some View {

        VStack(
            spacing:
                12
        ) {

            ZStack {

                Circle()

                    .fill(
                        Color.purple
                            .opacity(
                                glow
                                    ? 0.28
                                    : 0.16
                            )
                    )

                    .frame(
                        width:
                            112,
                        height:
                            112
                    )

                    .blur(
                        radius:
                            glow
                                ? 3
                                : 0
                    )


                Circle()

                    .fill(
                        .ultraThinMaterial
                    )

                    .frame(
                        width:
                            92,
                        height:
                            92
                    )

                    .overlay {

                        Circle()
                            .stroke(
                                Color.white
                                    .opacity(
                                        0.16
                                    ),
                                lineWidth:
                                    1
                            )
                    }


                Image(
                    systemName:
                        "crown.fill"
                )

                .font(
                    .system(
                        size:
                            40,
                        weight:
                            .bold
                    )
                )

                .foregroundStyle(

                    LinearGradient(
                        colors: [
                            Color(
                                red:
                                    0.95,
                                green:
                                    0.75,
                                blue:
                                    0.25
                            ),

                            Color.orange
                        ],

                        startPoint:
                            .topLeading,

                        endPoint:
                            .bottomTrailing
                    )
                )

                .shadow(
                    color:
                        Color.orange
                            .opacity(
                                0.35
                            ),
                    radius:
                        16
                )
            }


            Text(
                "NOVA STORE"
            )

            .font(
                .system(
                    size:
                        32,
                    weight:
                        .black,
                    design:
                        .rounded
                )
            )

            .foregroundStyle(
                .white
            )


            Text(
                "VIP MEMBER ACCESS"
            )

            .font(
                .system(
                    size:
                        11,
                    weight:
                        .bold,
                    design:
                        .rounded
                )
            )

            .tracking(
                2
            )

            .foregroundStyle(
                Color.white
                    .opacity(
                        0.50
                    )
            )
        }

        .opacity(
            appear
                ? 1
                : 0
        )

        .scaleEffect(
            appear
                ? 1
                : 0.92
        )
    }


    // MARK: Login Card

    private var loginCard:
        some View {

        VStack(
            spacing:
                18
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {

                Text(
                    "تسجيل الدخول"
                )

                .font(
                    .system(
                        size:
                            24,
                        weight:
                            .bold,
                        design:
                            .rounded
                    )
                )

                .foregroundStyle(
                    .white
                )


                Text(
                    "أدخل بيانات اشتراك NOVA VIP"
                )

                .font(
                    .system(
                        size:
                            13,
                        weight:
                            .medium
                    )
                )

                .foregroundStyle(
                    Color.white
                        .opacity(
                            0.50
                        )
                )
            }

            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )


            novaField(
                title:
                    "اسم المستخدم",
                icon:
                    "person.fill",
                text:
                    $username
            )


            passwordField


            novaField(
                title:
                    "كود الاشتراك",
                icon:
                    "key.fill",
                text:
                    $code
            )


            if let errorMessage {

                HStack(
                    spacing:
                        9
                ) {

                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )

                    Text(
                        errorMessage
                    )

                    Spacer()
                }

                .font(
                    .system(
                        size:
                            12,
                        weight:
                            .medium
                    )
                )

                .foregroundStyle(
                    Color.red
                        .opacity(
                            0.95
                        )
                )

                .padding(
                    12
                )

                .background(
                    Color.red
                        .opacity(
                            0.10
                        ),
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                13
                        )
                )
            }


            loginButton
        }

        .padding(
            22
        )

        .background(
            .ultraThinMaterial,
            in:
                RoundedRectangle(
                    cornerRadius:
                        28,
                    style:
                        .continuous
                )
        )

        .overlay {

            RoundedRectangle(
                cornerRadius:
                    28,
                style:
                    .continuous
            )

            .stroke(
                LinearGradient(
                    colors: [
                        Color.white
                            .opacity(
                                0.18
                            ),

                        Color.purple
                            .opacity(
                                0.35
                            ),

                        Color.white
                            .opacity(
                                0.04
                            )
                    ],

                    startPoint:
                        .topLeading,

                    endPoint:
                        .bottomTrailing
                ),

                lineWidth:
                    1
            )
        }

        .shadow(
            color:
                Color.black
                    .opacity(
                        0.40
                    ),
            radius:
                30,
            y:
                18
        )

        .opacity(
            appear
                ? 1
                : 0
        )

        .offset(
            y:
                appear
                    ? 0
                    : 25
        )
    }


    // MARK: Field

    private func novaField(
        title:
            String,
        icon:
            String,
        text:
            Binding<String>
    )
        -> some View {

        HStack(
            spacing:
                12
        ) {

            Image(
                systemName:
                    icon
            )

            .font(
                .system(
                    size:
                        15,
                    weight:
                        .semibold
                )
            )

            .foregroundStyle(
                Color.purple
            )


            TextField(
                title,
                text:
                    text
            )

            .font(
                .system(
                    size:
                        15,
                    weight:
                        .medium
                )
            )

            .foregroundStyle(
                .white
            )

            .tint(
                .purple
            )

            .textInputAutocapitalization(
                .never
            )

            .autocorrectionDisabled()
        }

        .padding(
            .horizontal,
            16
        )

        .frame(
            height:
                56
        )

        .background(
            Color.white
                .opacity(
                    0.07
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
        )

        .overlay {

            RoundedRectangle(
                cornerRadius:
                    16,
                style:
                    .continuous
            )

            .stroke(
                Color.white
                    .opacity(
                        0.10
                    ),
                lineWidth:
                    1
            )
        }
    }


    // MARK: Password

    private var passwordField:
        some View {

        HStack(
            spacing:
                12
        ) {

            Image(
                systemName:
                    "lock.fill"
            )

            .font(
                .system(
                    size:
                        15,
                    weight:
                        .semibold
                )
            )

            .foregroundStyle(
                Color.purple
            )


            Group {

                if showPassword {

                    TextField(
                        "كلمة المرور",
                        text:
                            $password
                    )

                } else {

                    SecureField(
                        "كلمة المرور",
                        text:
                            $password
                    )
                }
            }

            .font(
                .system(
                    size:
                        15,
                    weight:
                        .medium
                )
            )

            .foregroundStyle(
                .white
            )

            .tint(
                .purple
            )

            .textInputAutocapitalization(
                .never
            )

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

                .font(
                    .system(
                        size:
                            15,
                        weight:
                            .semibold
                    )
                )

                .foregroundStyle(
                    Color.white
                        .opacity(
                            0.55
                        )
                )
            }
        }

        .padding(
            .horizontal,
            16
        )

        .frame(
            height:
                56
        )

        .background(
            Color.white
                .opacity(
                    0.07
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
        )

        .overlay {

            RoundedRectangle(
                cornerRadius:
                    16,
                style:
                    .continuous
            )

            .stroke(
                Color.white
                    .opacity(
                        0.10
                    ),
                lineWidth:
                    1
            )
        }
    }


    // MARK: Login Button

    private var loginButton:
        some View {

        Button {

            Task {

                await performLogin()
            }

        } label: {

            HStack(
                spacing:
                    10
            ) {

                if isLoading {

                    ProgressView()
                        .tint(
                            .white
                        )

                } else {

                    Text(
                        "دخول إلى NOVA VIP"
                    )

                    .font(
                        .system(
                            size:
                                16,
                            weight:
                                .bold,
                            design:
                                .rounded
                        )
                    )


                    Image(
                        systemName:
                            "arrow.left"
                    )

                    .font(
                        .system(
                            size:
                                15,
                            weight:
                                .bold
                        )
                    )
                }
            }

            .foregroundStyle(
                .white
            )

            .frame(
                maxWidth:
                    .infinity
            )

            .frame(
                height:
                    56
            )

            .background(

                LinearGradient(
                    colors: [
                        Color(
                            red:
                                0.42,
                            green:
                                0.16,
                            blue:
                                0.90
                        ),

                        Color(
                            red:
                                0.68,
                            green:
                                0.25,
                            blue:
                                0.95
                        )
                    ],

                    startPoint:
                        .leading,

                    endPoint:
                        .trailing
                ),

                in:
                    RoundedRectangle(
                        cornerRadius:
                            16,
                        style:
                            .continuous
                    )
            )

            .shadow(
                color:
                    Color.purple
                        .opacity(
                            0.35
                        ),
                radius:
                    16,
                y:
                    8
            )
        }

        .buttonStyle(
            .plain
        )

        .disabled(
            isLoading
        )

        .opacity(
            isLoading
                ? 0.75
                : 1
        )
    }


    // MARK: Footer

    private var footer:
        some View {

        VStack(
            spacing:
                8
        ) {

            HStack(
                spacing:
                    7
            ) {

                Image(
                    systemName:
                        "lock.shield.fill"
                )

                Text(
                    "اتصال محمي ومصادق عليه"
                )
            }

            .font(
                .system(
                    size:
                        11,
                    weight:
                        .medium
                )
            )

            .foregroundStyle(
                Color.white
                    .opacity(
                        0.45
                    )
            )


            Text(
                "NOVA STORE • VIP SYSTEM"
            )

            .font(
                .system(
                    size:
                        9,
                    weight:
                        .bold,
                    design:
                        .rounded
                )
            )

            .tracking(
                1.5
            )

            .foregroundStyle(
                Color.white
                    .opacity(
                        0.22
                    )
            )
        }
    }


    // MARK: Login

    @MainActor
    private func performLogin()
        async {

        errorMessage = nil


        let cleanUsername =
            username
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        let cleanCode =
            code
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard !cleanUsername.isEmpty else {

            errorMessage =
                "أدخل اسم المستخدم."

            return
        }


        guard !password.isEmpty else {

            errorMessage =
                "أدخل كلمة المرور."

            return
        }


        guard !cleanCode.isEmpty else {

            errorMessage =
                "أدخل كود الاشتراك."

            return
        }


        isLoading =
            true


        defer {

            isLoading =
                false
        }


        do {

            try await auth.login(
                username:
                    cleanUsername,
                password:
                    password,
                code:
                    cleanCode
            )

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }
}
