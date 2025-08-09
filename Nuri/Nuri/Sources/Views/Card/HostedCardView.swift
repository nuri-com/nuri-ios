import SwiftUI
import WebKit
import StrigaAPI

struct HostedCardWebView: UIViewRepresentable {
    let sessionId: String
    let userId: String
    let applicationId: String
    let uiSecret: String
    @Binding var isPresented: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.userContentController.add(context.coordinator, name: "hostedCard")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        
        // Build the URL for sandbox
        let urlString = "https://cards-sandbox.striga.com?" +
                       "sessionId=\(sessionId)&" +
                       "userId=\(userId)&" +
                       "applicationId=\(applicationId)&" +
                       "uiSecret=\(uiSecret)"
        
        if let url = URL(string: urlString) {
            print("[HostedCardWebView] Loading URL: \(urlString)")
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: HostedCardWebView
        
        init(_ parent: HostedCardWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[HostedCardWebView] Page loaded successfully")
            
            // Inject JavaScript to listen for events
            let script = """
            window.addEventListener('message', function(event) {
                if (event.data && event.data.event) {
                    window.webkit.messageHandlers.hostedCard.postMessage(event.data);
                }
            });
            """
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[HostedCardWebView] Error injecting script: \(error)")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[HostedCardWebView] Navigation failed: \(error)")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "hostedCard",
                  let body = message.body as? [String: Any],
                  let event = body["event"] as? String else { return }
            
            print("[HostedCardWebView] Received event: \(event)")
            
            switch event {
            case "session-expired":
                // Handle session expiry
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            case "close":
                // Handle close event
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            default:
                break
            }
        }
    }
}

struct HostedCardView: View {
    @Binding var isPresented: Bool
    @State private var sessionId: String?
    @State private var isLoading = true
    @State private var errorMessage = ""
    
    private let striga = StrigaService.shared
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        
        // Ensure Striga is configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let sessionId = sessionId,
                   let config = striga.configuration,
                   let applicationId = config.applicationId,
                   let uiSecret = config.uiSecret {
                    HostedCardWebView(
                        sessionId: sessionId,
                        userId: UserSettings().strigaUserId ?? "",
                        applicationId: applicationId,
                        uiSecret: uiSecret,
                        isPresented: $isPresented
                    )
                    .edgesIgnoringSafeArea(.all)
                } else if isLoading {
                    ProgressView("Loading card...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if !errorMessage.isEmpty {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
            .navigationTitle("Card Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await createSession()
            }
        }
    }
    
    @MainActor
    private func createSession() async {
        print("[HostedCardView] 🚀 STARTING HOSTED CARD FLOW")
        print("[HostedCardView] ℹ️ This is the CORRECT approach for iOS apps")
        print("[HostedCardView] ℹ️ Flow: Create session → Open WebView → Handle consent in JS")
        
        do {
            guard let userId = UserSettings().strigaUserId else {
                print("[HostedCardView] ❌ ERROR: User ID not found")
                errorMessage = "User ID not found"
                isLoading = false
                return
            }
            
            // Get the user's real IP address (in production, this should come from the device)
            // For now, we'll use a placeholder
            let ipAddress = await getUserIPAddress()
            
            print("[HostedCardView] 📋 Session Details:")
            print("[HostedCardView]   - User ID: \(userId)")
            print("[HostedCardView]   - IP Address: \(ipAddress)")
            print("[HostedCardView]   - Environment: SANDBOX")
            print("[HostedCardView] 🔄 Creating session via REST API...")
            
            let response = try await striga.startHostedCardSession(.init(
                userId: userId,
                ipAddress: ipAddress
            ))
            
            // Check if we got an error response
            if response.isError {
                print("[HostedCardView] ❌ ERROR from API: \(response.errorMessage ?? "Unknown error")")
                
                if response.errorMessage?.contains("Multi-factor authentication not enabled") == true {
                    print("[HostedCardView] ⚠️ PREREQUISITE MISSING: Email/Phone not verified")
                    print("[HostedCardView] ℹ️ User must verify email AND phone first")
                    errorMessage = "Please verify both your email and phone number to enable card features"
                } else {
                    errorMessage = response.errorMessage ?? "Failed to create card session"
                }
                isLoading = false
                return
            }
            
            guard let sessionId = response.sessionId else {
                print("[HostedCardView] ❌ ERROR: No session ID in response")
                errorMessage = "Invalid response from server"
                isLoading = false
                return
            }
            
            print("[HostedCardView] ✅ Session created successfully!")
            print("[HostedCardView] 📱 Session ID: \(sessionId)")
            print("[HostedCardView] 🌐 WebView will load: https://cards-sandbox.striga.com")
            print("[HostedCardView] ℹ️ Inside WebView:")
            print("[HostedCardView]   1. JavaScript SDK calls requestConsent()")
            print("[HostedCardView]   2. User enters OTP (sandbox: 123456)")
            print("[HostedCardView]   3. Card details displayed securely")
            self.sessionId = sessionId
            isLoading = false
            
        } catch {
            print("[HostedCardView] Error creating session: \(error)")
            errorMessage = "Failed to create card session: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func getUserIPAddress() async -> String {
        // Try to get the real IP address from ipify.org
        do {
            if let url = URL(string: "https://api.ipify.org"),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let ipAddress = String(data: data, encoding: .utf8) {
                let cleanIP = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                print("[HostedCardView] Got user IP: \(cleanIP)")
                return cleanIP
            }
        } catch {
            print("[HostedCardView] Failed to get IP address: \(error)")
        }
        return "127.0.0.1" // Fallback for development
    }
}
