import SwiftUI
import WebKit
import StrigaAPI

/// Streamlined card details flow that automatically progresses through steps
struct BasicCardDetails {
    let holder: String
    let expiry: String
}

struct CardDetailsFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: FlowStep = .initializing
    @State private var challengeId: String?
    @State private var otpCode: String = ""
    @State private var errorMessage: String?
    @State private var webViewRef: WKWebView?
    @State private var authToken: String?
    @FocusState private var isOTPFocused: Bool
    @State private var hasStartedConsent = false
    
    private let bridge = StrigaBridge()
    private let userId: String
    private let cardId: String
    private let striga = StrigaService.shared
    
    private var uiSecret: String {
        StrigaCredentials.current.uiSecret ?? ""
    }
    
    private var applicationId: String {
        StrigaCredentials.current.applicationId ?? ""
    }
    
    enum FlowStep: Equatable {
        case initializing
        case requestingConsent
        case enteringOTP
        case verifyingOTP
        case displayingCard
        case error(String)
    }
    
    init(userId: String, cardId: String) {
        self.userId = userId
        self.cardId = cardId
        
        print("════════════════════════════════════════")
        print("🎯 [CardDetailsFlow] Starting streamlined flow")
        print("📱 User ID: \(userId)")
        print("📱 Card ID: \(cardId)")
        print("════════════════════════════════════════")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content based on current step
                VStack {
                    switch currentStep {
                    case .initializing, .requestingConsent:
                        loadingView
                    case .enteringOTP:
                        otpInputView
                    case .verifyingOTP:
                        verifyingView
                    case .displayingCard:
                        cardDisplayView
                    case .error(let message):
                        errorView(message: message)
                    }
                }
                
                // Single WebView for entire lifecycle - never recreate it
                StrigaCardWebView(
                    uiSecret: uiSecret,
                    applicationId: applicationId,
                    userId: userId,
                    bridge: bridge,
                    webViewRef: $webViewRef
                )
                .frame(maxWidth: .infinity)
                .frame(height: currentStep == .displayingCard ? 350 : 1)
                .background(Color.white)
                .opacity(currentStep == .displayingCard ? 1 : 0.001)
                .allowsHitTesting(currentStep == .displayingCard)
                .ignoresSafeArea(.container, edges: currentStep == .displayingCard ? .horizontal : [])
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(currentStep == .displayingCard ? "Card Details" : "")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .opacity(currentStep == .displayingCard ? 1 : 0)
                }
            }
            .background(currentStep == .displayingCard ? Color.white : Color(UIColor.systemGray6))
            .ignoresSafeArea(.keyboard)
        }
        .onAppear {
            setupBridgeAndStartFlow()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading secure card display...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Please wait while we prepare your card details")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var otpInputView: some View {
        VStack(spacing: 0) {
            // Header matching UnifiedInputView style
            NuriHeader<AnyView, EmptyView>(title: "Verification Code") {
                AnyView(
                    Button(action: { dismiss() }) {
                        Image("arrow-back")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(width: 32, height: 32)
                    }
                )
            } trailing: {
                EmptyView()
            }
            .padding(.top, 10)
            
            VStack(alignment: .leading, spacing: 24) {
                // Left-aligned headline
                Text("Enter the code sent to you")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                
                // Subtitle
                Text("We've sent a 6-digit code to verify your identity")
                    .font(.brandBody)
                    .foregroundColor(.secondary)
                
                // OTP Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verification Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("000000", text: $otpCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isOTPFocused)
                        .font(.custom("Inter", size: 24).weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: otpCode) { _, newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                otpCode = String(newValue.prefix(6))
                            }
                            // Auto-submit when 6 digits are entered
                            if newValue.count == 6 {
                                verifyOTP()
                            }
                        }
                    
                    #if DEBUG
                    Text("Sandbox: Use 123456")
                        .font(.caption)
                        .foregroundColor(.orange)
                    #endif
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .navigationBarHidden(true)
        .background(Color(UIColor.systemGray6))
        .onAppear {
            // Auto-focus the OTP field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isOTPFocused = true
            }
        }
    }
    
    private var verifyingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Verifying code...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var cardDisplayView: some View {
        Color.clear // The WebView will show everything
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                currentStep = .initializing
                setupBridgeAndStartFlow()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func setupBridgeAndStartFlow() {
        print("🔧 [CardDetailsFlow] Setting up bridge and starting flow")
        
        // Setup bridge callbacks
        bridge.onChallenge = { ch in
            print("✅ [CardDetailsFlow] Got challengeId: \(ch)")
            self.challengeId = ch
            DispatchQueue.main.async {
                self.currentStep = .enteringOTP
            }
        }
        
        bridge.onRendered = {
            print("✅ [CardDetailsFlow] Card rendered successfully in secure iframes")
            // Don't change state here - we're already showing native UI
        }
        
        bridge.onError = { msg in
            print("❌ [CardDetailsFlow] Error: \(msg)")
            DispatchQueue.main.async {
                self.currentStep = .error(msg)
            }
        }
        
        bridge.onLog = { msg in
            print("📱 [JS Log]: \(msg)")
        }
        
        bridge.onReady = {
            print("✅ [CardDetailsFlow] Striga SDK is ready")
            DispatchQueue.main.async {
                if !self.hasStartedConsent {
                    print("📱 [CardDetailsFlow] First time ready - starting consent flow")
                    self.hasStartedConsent = true
                    self.startConsentFlow()
                } else {
                    print("⚠️ [CardDetailsFlow] Already started consent, ignoring ready signal")
                }
            }
        }
    }
    
    private func startConsentFlow() {
        print("🚀 [CardDetailsFlow] Starting consent flow")
        currentStep = .requestingConsent
        
        // Request consent through the WebView immediately
        print("📱 [CardDetailsFlow] Calling requestConsent")
        self.webViewRef?.strigaRequestConsent(userId: self.userId, channel: "sms")
    }
    
    private func fetchBasicCardDetails() async -> BasicCardDetails? {
        do {
            // Fetch without auth token to get basic details
            let response = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            let expiry = String(format: "%02d/%02d", response.expiryMonth, response.expiryYear % 100)
            return BasicCardDetails(holder: response.name, expiry: expiry)
        } catch {
            print("❌ [CardDetailsFlow] Error fetching basic details: \(error)")
            return BasicCardDetails(holder: "CARD HOLDER", expiry: "MM/YY")
        }
    }
    
    private func verifyOTP() {
        guard let ch = challengeId else {
            print("❌ [CardDetailsFlow] No challengeId available")
            errorMessage = "Please wait for the code to be sent"
            return
        }
        
        print("🚀 [CardDetailsFlow] Verifying OTP: \(otpCode)")
        currentStep = .verifyingOTP
        errorMessage = nil
        
        // Hide keyboard
        isOTPFocused = false
        
        Task {
            do {
                // Send OTP to proxy server
                let proxyURL = "https://passkey.nuri.com/striga/confirm-consent"
                var request = URLRequest(url: URL(string: proxyURL)!)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let payload: [String: Any] = [
                    "userId": userId,
                    "challengeId": ch,
                    "verificationCode": otpCode
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                print("📱 [CardDetailsFlow] Sending to proxy server")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 200 {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let token = json?["cardAuthToken"] as? String else {
                        throw NSError(domain: "CardDetailsFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "No auth token in response"])
                    }
                    
                    print("✅ [CardDetailsFlow] Got auth token")
                    
                    // Also fetch basic card details for name and expiry
                    let cardDetails = await fetchBasicCardDetails()
                    
                    await MainActor.run {
                        self.authToken = token
                        self.currentStep = .displayingCard
                        
                        // Pass card details to WebView
                        if let details = cardDetails {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.webViewRef?.setCardDetails(
                                    holder: details.holder,
                                    expiry: details.expiry
                                )
                            }
                        }
                        
                        // Render card in WebView with auth token for FULL details
                        // Wait a bit longer to ensure WebView is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("🎨 [CardDetailsFlow] Calling renderCard with auth token")
                            print("  - cardId: \(self.cardId)")
                            print("  - authToken length: \(token.count)")
                            print("  - WebView exists: \(self.webViewRef != nil)")
                            
                            if self.webViewRef != nil {
                                self.webViewRef?.strigaRender(cardId: self.cardId, authToken: token)
                            } else {
                                print("❌ [CardDetailsFlow] WebView not ready, cannot render card")
                            }
                        }
                    }
                } else {
                    var errorMsg = "Verification failed"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        errorMsg = error
                    }
                    
                    // Handle specific error cases
                    if errorMsg.contains("Invalid verification code") {
                        errorMsg = "Invalid code. Please check and try again."
                    } else if errorMsg.contains("expired") || errorMsg.contains("Challenge not found") {
                        errorMsg = "Code expired. Please request a new one."
                    }
                    
                    throw NSError(domain: "CardDetailsFlow", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
            } catch {
                print("❌ [CardDetailsFlow] Error verifying OTP: \(error)")
                await MainActor.run {
                    self.currentStep = .enteringOTP
                    self.errorMessage = error.localizedDescription
                    self.otpCode = "" // Clear the code for retry
                    // Re-focus the field
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isOTPFocused = true
                    }
                }
            }
        }
    }
}

