import SwiftUI
import WebKit
import StrigaAPI

struct CardScreenNew: View {
    @State private var webViewRef: WKWebView?
    private let bridge = StrigaBridge()
    @Environment(\.dismiss) private var dismiss
    
    let userId: String
    let cardId: String
    
    @State private var challengeId: String?
    @State private var otp = ""
    @State private var showOtp = false
    @State private var status = "Tap 'Show card details' to begin"
    @State private var isLoading = false
    @State private var cardRendered = false
    @State private var flowStarted = false
    
    // Get credentials from configuration
    private var uiSecret: String {
        StrigaCredentials.current.uiSecret ?? ""
    }
    
    private var applicationId: String {
        StrigaCredentials.current.applicationId ?? ""
    }
    
    init(userId: String, cardId: String) {
        self.userId = userId
        self.cardId = cardId
        
        print("════════════════════════════════════════")
        print("🎯 [CardScreenNew] Initializing")
        print("📱 User ID: \(userId)")
        print("📱 Card ID: \(cardId)")
        print("════════════════════════════════════════")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                Text("Secure Card Display")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                // Card display area with WebView
                VStack {
                    if !cardRendered {
                        Text("Card Details")
                            .font(.headline)
                            .padding(.bottom, 8)
                    }
                    
                    // WebView for Striga card rendering
                    StrigaCardWebView(
                        uiSecret: uiSecret,
                        applicationId: applicationId,
                        userId: userId,
                        bridge: bridge,
                        webViewRef: $webViewRef
                    )
                    .frame(height: 160) // Enough height for PAN and CVV
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardRendered ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(radius: cardRendered ? 4 : 2)
                }
                .padding(.horizontal)
                
                // Status display
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(cardRendered ? .green : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Action button
                if !cardRendered {
                    Button(action: requestCardDetails) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Show card details")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || flowStarted)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .onAppear(perform: setupBridge)
            .sheet(isPresented: $showOtp) {
                otpSheet
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var otpSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter 6-digit code")
                    .font(.headline)
                
                #if DEBUG
                Text("Sandbox: Use 123456")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #endif
                
                TextField("123456", text: $otp)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 150)
                
                HStack(spacing: 20) {
                    Button("Resend") {
                        resend()
                    }
                    .disabled(challengeId == nil)
                    
                    Button("Confirm") {
                        confirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(challengeId == nil || otp.count < 6)
                }
            }
            .padding()
            .navigationTitle("Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showOtp = false
                    }
                }
            }
        }
    }
    
    private func setupBridge() {
        print("🔧 [CardScreenNew] Setting up bridge callbacks")
        
        bridge.onChallenge = { ch in
            print("✅ [CardScreenNew] Got challengeId: \(ch)")
            challengeId = ch
            status = "OTP sent (sandbox code is 123456)"
            isLoading = false
            showOtp = true
        }
        
        bridge.onRendered = {
            print("✅ [CardScreenNew] Card rendered successfully")
            status = "✅ Card details displayed securely"
            isLoading = false
            cardRendered = true
        }
        
        bridge.onError = { msg in
            print("❌ [CardScreenNew] Error: \(msg)")
            status = "Error: \(msg)"
            isLoading = false
        }
        
        bridge.onLog = { msg in
            print("📱 [JS Log]: \(msg)")
        }
    }
    
    private func requestCardDetails() {
        guard !flowStarted else {
            print("⚠️ [CardScreenNew] Flow already started, ignoring")
            return
        }
        
        flowStarted = true
        print("🚀 [CardScreenNew] Starting card details flow")
        status = "Loading Striga SDK..."
        isLoading = true
        
        // Give SDK time to load and initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            print("📱 [CardScreenNew] Calling requestConsent after delay")
            self.status = "Requesting consent..."
            self.webViewRef?.strigaRequestConsent(userId: self.userId, channel: "sms")
        }
    }
    
    private func confirm() {
        print("🚀 [CardScreenNew] Confirming OTP")
        guard let ch = challengeId,
              let url = URL(string: "https://passkey.nuri.com/striga/confirm-consent")
        else {
            print("❌ [CardScreenNew] Missing challengeId or invalid URL")
            return
        }
        
        status = "Confirming OTP..."
        isLoading = true
        showOtp = false
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "challengeId": ch,
            "verificationCode": otp
        ]
        
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("📱 [CardScreenNew] Sending to proxy:")
        print("  - URL: \(url)")
        print("  - userId: \(userId)")
        print("  - challengeId: \(ch)")
        print("  - code: \(otp)")
        
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                print("❌ [CardScreenNew] Network error: \(err)")
                DispatchQueue.main.async {
                    status = "Network error: \(err.localizedDescription)"
                    isLoading = false
                }
                return
            }
            
            guard let data = data else {
                print("❌ [CardScreenNew] No data received")
                DispatchQueue.main.async {
                    status = "No response from server"
                    isLoading = false
                }
                return
            }
            
            if let httpResp = resp as? HTTPURLResponse {
                print("📱 [CardScreenNew] Response status: \(httpResp.statusCode)")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ [CardScreenNew] Failed to parse JSON")
                print("📱 [CardScreenNew] Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                DispatchQueue.main.async {
                    status = "Invalid response format"
                    isLoading = false
                }
                return
            }
            
            if let token = json["cardAuthToken"] as? String {
                print("✅ [CardScreenNew] Got auth token (length: \(token.count))")
                print("🔑 [CardScreenNew] Auth token preview: \(String(token.prefix(50)))...")
                
                DispatchQueue.main.async {
                    status = "Rendering card details..."
                    print("🎨 [CardScreenNew] Calling renderCard with:")
                    print("  - cardId: \(cardId)")
                    print("  - authToken length: \(token.count)")
                    webViewRef?.strigaRender(cardId: cardId, authToken: token)
                }
            } else {
                print("❌ [CardScreenNew] No auth token in response")
                print("📱 [CardScreenNew] Response: \(json)")
                DispatchQueue.main.async {
                    let error = json["error"] as? String ?? "Unknown error"
                    status = "Confirm failed: \(error)"
                    isLoading = false
                }
            }
        }.resume()
    }
    
    private func resend() {
        print("🔄 [CardScreenNew] Resending code")
        guard let ch = challengeId,
              let url = URL(string: "https://passkey.nuri.com/striga/resend-consent-code")
        else {
            print("❌ [CardScreenNew] Missing challengeId or invalid URL")
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "challengeId": ch
        ]
        
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { _, _, _ in
            print("✅ [CardScreenNew] Resend request sent")
        }.resume()
        
        status = "Code resent - check your phone/email"
    }
}