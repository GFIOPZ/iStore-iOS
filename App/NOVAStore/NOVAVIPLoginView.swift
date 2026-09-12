import SwiftUI
import AudioToolbox

// MARK: - VIP Data Models
struct NOVAVIPAccount: Codable {
    let id: String
    let username: String
    let password: String
    let code: String
    let enabled: Bool
    
    let created_at: String
    let duration: String
    let duration_type: String
    
    let cert_password: String?
    let p12_base64: String?
    let prov_base64: String?
    
    // التحقق من انتهاء الصلاحية داخلياً
    var isExpired: Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let startDate = formatter.date(from: created_at),
              let durationValue = Int(duration) else { return true }
        
        var endDate: Date?
        if duration_type == "days" {
            endDate = Calendar.current.date(byAdding: .day, value: durationValue, to: startDate)
        } else if duration_type == "minutes" {
            endDate = Calendar.current.date(byAdding: .minute, value: durationValue, to: startDate)
        } else if duration_type == "months" {
            endDate = Calendar.current.date(byAdding: .month, value: durationValue, to: startDate)
        }
        
        guard let finalEndDate = endDate else { return true }
        return Date() > finalEndDate
    }
}

struct NOVAVIPResponse: Codable {
    let accounts: [NOVAVIPAccount]
}

// MARK: - VIP Login View
struct NOVAVIPLoginView: View {
    @AppStorage("isVIPLoggedIn") private var isVIPLoggedIn = false
    
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
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("تسجيل الدخول")
                                .font(.headline.weight(.bold))
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
        .alert("فشل تسجيل الدخول", isPresented: $showError) {
            Button("حسناً", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func verifyVIP() {
        isLoading = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // الرابط الخاص بسيرفرك
        guard let url = URL(string: "https://nova-api.hassanyipa.workers.dev/?file=vip.json") else { return }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // إرسال القفل السري للسيرفر
        request.setValue("SuperNova2026!", forHTTPHeaderField: "Nova-Secret")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let data = data, error == nil else {
                    showError(msg: "تعذر الاتصال بالسيرفر. تأكد من اتصال الإنترنت.")
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(NOVAVIPResponse.self, from: data)
                    
                    if let account = result.accounts.first(where: { $0.username == username && $0.password == password && $0.code == code }) {
                        
                        if !account.enabled {
                            showError(msg: "هذا الحساب معطل حالياً من الإدارة.")
                            return
                        }
                        if account.isExpired {
                            showError(msg: "عذراً، لقد انتهت مدة اشتراكك في المتجر.")
                            return
                        }
                        
                        AudioServicesPlaySystemSound(1407)
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        
                        if let p12 = account.p12_base64, !p12.isEmpty,
                           let prov = account.prov_base64, !prov.isEmpty {
                            autoImportCertificates(p12Base64: p12, provBase64: prov, password: account.cert_password ?? "")
                        }
                        
                        withAnimation(.easeInOut) {
                            isVIPLoggedIn = true
                        }
                    } else {
                        showError(msg: "المعلومات غير صحيحة. يرجى التأكد من اليوزر، الباسورد، والكود.")
                    }
                } catch {
                    showError(msg: "حدث خطأ أثناء قراءة بيانات الخادم.")
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
