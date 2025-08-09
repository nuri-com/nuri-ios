import SwiftUI
import WebKit
import StrigaAPI

/// View that manages the entire card details display flow using Striga's JS SDK.
/// It contains a hidden webview for consent requests and a visible webview for card rendering.
struct CardDetailsWebView: View {
    let userId: String
    let cardId: String
    @Binding var isPresented: Bool
    
    @State private var showOTPSheet = false
    @State private var challengeId: String?
    @State private var authToken: String?
    @State private var showCardDisplay = false
    @State private var webViewForConsent: WKWebView?
    
    init(userId: String, cardId: String, isPresented: Binding<Bool>) {
        self.userId = userId
        self.cardId = cardId
        self._isPresented = isPresented
        
        print("📱 [CardDetailsWebView] Initializing card details flow")
        print("📱 [CardDetailsWebView] User ID: \(userId)")
        print("📱 [CardDetailsWebView] Card ID: \(cardId)")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Hidden webview for consent request
                CardConsentWebView(
                    userId: userId,
                    cardId: cardId,
                    isPresented: .constant(true),
                    onChallenge: { challenge in
                        print("✅ [CardDetailsWebView] Step 1 Complete: Got challengeId from JS")
                        print("📱 [CardDetailsWebView] Challenge ID: \(challenge)")
                        print("📱 [CardDetailsWebView] Opening OTP sheet...")
                        challengeId = challenge
                        showOTPSheet = true
                    }
                )
                .frame(width: 0, height: 0)
                .opacity(0)
                
                // Card display webview (shown after auth)
                if showCardDisplay, let authToken = authToken {
                    CardRenderWebView(
                        cardId: cardId,
                        authToken: authToken
                    )
                    .edgesIgnoringSafeArea(.bottom)
                } else {
                    VStack {
                        ProgressView("Requesting card access...")
                        Text("You will receive a verification code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Card Details")
            .onAppear {
                print("🚀 [CardDetailsWebView] View appeared, starting card display flow")
                print("📱 [CardDetailsWebView] Step 1: Hidden webview will request consent")
                print("📱 [CardDetailsWebView] Step 2: User will enter OTP")
                print("📱 [CardDetailsWebView] Step 3: Proxy will verify OTP")
                print("📱 [CardDetailsWebView] Step 4: Card will render in secure iframes")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showOTPSheet) {
            if let challengeId = challengeId {
                CardOTPConsentView(
                    userId: userId,
                    cardId: cardId,
                    challengeId: challengeId,
                    isPresented: $showOTPSheet,
                    onSuccess: { token in
                        print("✅ [CardDetailsWebView] Step 3 Complete: Got auth token from proxy")
                        print("📱 [CardDetailsWebView] Auth token received (length: \(token.count))")
                        print("📱 [CardDetailsWebView] Showing card display webview...")
                        authToken = token
                        showCardDisplay = true
                    }
                )
            }
        }
    }
}

/// WebView specifically for rendering card details using auth token
struct CardRenderWebView: UIViewRepresentable {
    let cardId: String
    let authToken: String
    
    init(cardId: String, authToken: String) {
        self.cardId = cardId
        self.authToken = authToken
        
        print("🚀 [CardRenderWebView] Step 4: Initializing card rendering webview")
        print("📱 [CardRenderWebView] Card ID: \(cardId)")
        print("📱 [CardRenderWebView] Auth token length: \(authToken.count)")
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Get credentials
        let creds = StrigaCredentials.current
        let uiSecret = creds.uiSecret ?? ""
        let applicationId = creds.applicationId ?? ""
        
        // HTML with secure iframes for card display
        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <script src="https://www.vault.striga.eu/web/sandbox/v1.1/client.min.js"></script>
            <style>
                body {
                    font-family: -apple-system, system-ui;
                    padding: 20px;
                    background: #f5f5f7;
                }
                .card-container {
                    background: white;
                    border-radius: 12px;
                    padding: 24px;
                    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
                    max-width: 400px;
                    margin: 0 auto;
                }
                .card-field {
                    margin-bottom: 24px;
                }
                .card-label {
                    font-size: 12px;
                    font-weight: 600;
                    color: #666;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    margin-bottom: 8px;
                }
                #cardNumber, #cvv {
                    font-size: 20px;
                    font-family: 'SF Mono', 'Monaco', monospace;
                    padding: 12px;
                    background: #f5f5f7;
                    border-radius: 8px;
                    min-height: 48px;
                    border: 1px solid #e5e5e7;
                }
                #cardNumber {
                    letter-spacing: 2px;
                }
                .loading {
                    text-align: center;
                    color: #999;
                    padding: 20px;
                }
                .error {
                    color: #ff3b30;
                    text-align: center;
                    padding: 20px;
                }
            </style>
        </head>
        <body>
            <div class="card-container">
                <div class="loading" id="status">Loading card details...</div>
                
                <div id="cardContent" style="display: none;">
                    <div class="card-field">
                        <div class="card-label">Card Number</div>
                        <div id="cardNumber"></div>
                    </div>
                    
                    <div class="card-field">
                        <div class="card-label">CVV</div>
                        <div id="cvv"></div>
                    </div>
                </div>
            </div>
            
            <script>
                // Initialize Striga UI Plugin
                console.log('🚀 [CardRender] Initializing Striga UI Plugin for card display...');
                console.log('📱 [CardRender] Application ID: \(applicationId)');
                
                StrigaUXPlugin.create('\(uiSecret)', {
                    applicationId: '\(applicationId)'
                });
                
                console.log('✅ [CardRender] Striga UI Plugin ready for rendering');
                
                // Render card details immediately
                async function renderCardDetails() {
                    try {
                        console.log('🚀 [CardRender] Starting card rendering process...');
                        console.log('📱 [CardRender] Card ID: \(cardId)');
                        console.log('📱 [CardRender] Auth token present: YES');
                        
                        document.getElementById('status').textContent = 'Decrypting card data...';
                        
                        // Show card number in secure iframe
                        console.log('📱 [CardRender] Rendering card number element...');
                        await StrigaUXPlugin.render('cardNumber', {
                            cardId: '\(cardId)',
                            authToken: '\(authToken)'
                        });
                        console.log('✅ [CardRender] Card number rendered successfully');
                        
                        // Show CVV in secure iframe
                        console.log('📱 [CardRender] Rendering CVV element...');
                        await StrigaUXPlugin.render('cvv', {
                            cardId: '\(cardId)',
                            authToken: '\(authToken)'
                        });
                        console.log('✅ [CardRender] CVV rendered successfully');
                        
                        // Show the card content
                        document.getElementById('status').style.display = 'none';
                        document.getElementById('cardContent').style.display = 'block';
                        
                        console.log('✅ [CardRender] SUCCESS: All card elements rendered');
                        console.log('🎉 [CardRender] Card details are now visible in secure iframes');
                        
                    } catch (error) {
                        console.error('❌ [CardRender] ERROR: Failed to render card');
                        console.error('📱 [CardRender] Error details:', error);
                        console.error('📱 [CardRender] Error message:', error.message);
                        console.error('📱 [CardRender] Error stack:', error.stack);
                        
                        document.getElementById('status').className = 'error';
                        document.getElementById('status').textContent = 'Failed to load card details: ' + error.message;
                    }
                }
                
                // Start rendering after page loads
                if (document.readyState === 'complete') {
                    console.log('📱 [CardRender] Document already loaded, starting render...');
                    setTimeout(renderCardDetails, 100);
                } else {
                    window.addEventListener('load', function() {
                        console.log('📱 [CardRender] Page fully loaded, starting render...');
                        setTimeout(renderCardDetails, 100);
                    });
                }
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}