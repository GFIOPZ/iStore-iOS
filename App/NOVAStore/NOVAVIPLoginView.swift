import SwiftUI
import AudioToolbox

// الموديلات الخاصة بالرد من السيرفر
struct NOVAVIPAccount: Codable {
    let username: String
    let cert_password: String?
    let p12_base64: String?
    let prov_base64: String?
}

struct APILoginResponse: Codable {
    let success: Bool?
    let error: String?
    let account: NOVAVIPAccount?
}

// MARK: - VIP Login View
struct NOVAVIPLoginView: View {
    @AppStorage("isVIPLoggedIn") private var isVIPLoggedIn = false
    @AppStorage("vip_username") private var vipUsername = ""
    @AppStorage("vip_password") private var vipPassword = ""
    @AppStorage("vip_code") private var vipCode = ""
    
    @EnvironmentObject private var certStore: CertificateStore
    @EnvironmentObject private var profileStore: ProfileStore
    
    @State private var username = ""
    @State private var password = ""
    @State private var code = ""
    
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    private let gradientStart = Color(hex: "7C3AED")
    private let gradientEnd = Color(hex: "A855F7")

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color(hex: "FFD700").opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Text("NOVA VIP")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [gradientStart, gradientEnd],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    
                    Text("الرجاء إدخال بيانات المطالبة للوصول للمتجر")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
                
                VStack(spacing: 16) {
                    CustomTextField(icon: "person.fill", placeholder: "اسم المستخدم", text: $username)
                    CustomTextField(icon: "lock.fill", placeholder: "كلمة السر", text: $password, isSecure: true)
                    CustomTextField(icon: "key.fill", placeholder: "كود التفعيل", text: $code)
                }
                .padding(.horizontal, 24)
                
                Button(action: verifyVIP) {
                    HStack {
                        if isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("تسجيل الدخول").font(.headline.weight(.bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(
                        LinearGradient(colors: [gradientStart, gradientEnd],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: gradientStart.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty || code.isEmpty)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                Spacer()
                Spacer()
            }
        }
        .alert("إشعار", isPresented: $showError) {
            Button("حسناً", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Verification Logic (True API Mode)
    private func verifyVIP() {
        isLoading = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // الاتصال بسيرفرك الجديد
        guard let url = URL(string: "https://nova-ipa.hassanyipa.workers.dev/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SuperNova2026!", forHTTPHeaderField: "Nova-Secret") // القفل السري
        
        // إرسال البيانات
        let bodyData: [String: String] = [
            "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password.trimmingCharacters(in: .whitespacesAndNewlines),
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyData)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let data = data, error == nil else {
                    showError(msg: "تعذر الاتصال بالسيرفر. تأكد من اتصال الإنترنت.")
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(APILoginResponse.self, from: data)
                    
                    if result.success == true, let account = result.account {
                        // نجاح الدخول
                        AudioServicesPlaySystemSound(1407)
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        
                        // استيراد الشهادة
                        if let p12 = account.p12_base64, !p12.isEmpty,
                           let prov = account.prov_base64, !prov.isEmpty {
                            autoImportCertificates(p12Base64: p12, provBase64: prov, password: account.cert_password ?? "")
                        }
                        
                        // حفظ البيانات للتحقق بالخلفية
                        vipUsername = username
                        vipPassword = password
                        vipCode = code
                        
                        withAnimation(.easeInOut) {
                            isVIPLoggedIn = true
                        }
                    } else {
                        showError(msg: result.error ?? "معلومات غير صحيحة.")
                    }
                } catch {
                    showError(msg: "خطأ في قراءة بيانات السيرفر.")
                }
            }
        }.resume()
    }
    
    private func autoImportCertificates(p12Base64: String, provBase64: String, password: String) {
        guard let p12Data = Data(base64Encoded: p12Base64, options: .ignoreUnknownCharacters),
              let provData = Data(base64Encoded: provBase64, options: .ignoreUnknownCharacters) else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let p12URL = tempDir.appendingPathComponent("nova_vip_cert.p12")
        let provURL = tempDir.appendingPathComponent("nova_vip_profile.mobileprovision")
        
        do {
            try p12Data.write(to: p12URL)
            try provData.write(to: provURL)
            
            _ = profileStore.importProfile(from: provURL)
            _ = certStore.importCertificate(from: p12URL, password: password, rememberPassword: true)
            
            try? FileManager.default.removeItem(at: p12URL)
            try? FileManager.default.removeItem(at: provURL)
        } catch { }
    }
    
    private func showError(msg: String) {
        errorMessage = msg
        showError = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

private struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 24)
            if isSecure { SecureField(placeholder, text: $text).autocorrectionDisabled().textInputAutocapitalization(.never) }
            else { TextField(placeholder, text: $text).autocorrectionDisabled().textInputAutocapitalization(.never) }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
}
