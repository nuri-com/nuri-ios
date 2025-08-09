import SwiftUI
import WebKit
import StrigaAPI

/// Hidden WebView that loads Striga's JS SDK and handles card operations.
/// Step 1: Request consent and get challengeId
/// Step 2: After OTP verification, render card details using authToken
struct CardConsentWebView: UIViewRepresentable {
    let userId: String
    let cardId: String?
    @Binding var isPresented: Bool
    let onChallenge: (String) -> Void // callback with challengeId
    
    // For rendering card after OTP verification
    var authToken: String?
    var shouldRenderCard: Bool = false
    
    // Reference to the webview for JS calls
    static var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.userContentController.add(context.coordinator, name: "strigaNative")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator // Set navigation delegate
        webView.isHidden = true // Hidden webview
        webView.alpha = 0 // Extra hidden
        
        // Store webview and userId in coordinator
        context.coordinator.webView = webView
        context.coordinator.userId = userId
        
        // Get credentials
        let creds = StrigaCredentials.current
        let uiSecret = creds.uiSecret ?? ""
        let applicationId = creds.applicationId ?? ""

        // SIMPLIFIED HTML FOR TESTING
        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <style>
                body {
                    font-family: -apple-system, system-ui;
                    padding: 20px;
                    background: white;
                    display: none; /* Hidden by default */
                }
                .card-container {
                    margin: 20px 0;
                }
                #cardNumber, #cvv {
                    font-size: 18px;
                    font-weight: bold;
                    padding: 10px;
                    background: white;
                    border-radius: 4px;
                    min-height: 40px;
                    border: 1px solid #ddd;
                }
            </style>
        </head>
        <body>
            <h1>Test Page</h1>
            <div id="status">Initial</div>
            
            <script>
                // Immediate test
                console.log('SCRIPT EXECUTING');
                document.getElementById('status').innerHTML = 'Script Running';
                
                // Define functions immediately
                window.testFunction = function() { return 'Test OK'; };
                window.requestConsent = function(userId, channel) {
                    console.log('requestConsent called:', userId, channel);
                    // Send fake challengeId for testing
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.strigaNative) {
                        window.webkit.messageHandlers.strigaNative.postMessage({
                            type: 'challengeId',
                            challengeId: 'test-challenge-' + Date.now(),
                            expires: new Date().toISOString()
                        });
                    }
                    return Promise.resolve({ challengeId: 'test-123' });
                };
                
                console.log('Functions ready');
                console.log('testFunction:', typeof window.testFunction);
                console.log('requestConsent:', typeof window.requestConsent);
            </script>
            
            <!-- Original script content below (commented for now) -->
            <!--
            <script>
                console.log('📱 [JS] Script starting...');
                
                // Wait for Striga SDK to be available
                function waitForStriga() {
                    if (typeof StrigaUXPlugin !== 'undefined') {
                        console.log('✅ [JS] StrigaUXPlugin is available');
                        initializePlugin();
                    } else {
                        console.log('⚠️ [JS] StrigaUXPlugin not yet available, waiting...');
                        setTimeout(waitForStriga, 100);
                    }
                }
                
                function initializePlugin() {
                    console.log('🚀 [JS] Initializing Striga UI Plugin...');
                    console.log('📱 [JS] Application ID: \(applicationId)');
                    console.log('📱 [JS] Environment: SANDBOX');
                    
                    try {
                        StrigaUXPlugin.create('\(uiSecret)', {
                            applicationId: '\(applicationId)'
                        });
                        
                        console.log('✅ [JS] Striga UI Plugin initialized');
                        setupFunctions();
                    } catch (error) {
                        console.error('❌ [JS] Failed to initialize Striga:', error);
                    }
                }
                
                function setupFunctions() {
                    // Function 1: Request consent (triggers OTP)
                    // Make function available globally on window object
                    window.requestConsent = async function(userId, channel) {
                    try {
                        console.log('🚀 [JS] Starting requestConsent()');
                        console.log('📱 [JS] User ID:', userId);
                        console.log('📱 [JS] Channel:', channel || 'both (email + sms)');
                        
                        const params = { userId };
                        if (channel) {
                            params.channel = channel; // 'sms' or 'email'
                        }
                        
                        console.log('📱 [JS] Calling Striga requestConsent() API...');
                        const result = await StrigaUXPlugin.requestConsent(params);
                        console.log('✅ [JS] SUCCESS: Got response from Striga');
                        console.log('📱 [JS] Challenge ID:', result.challengeId);
                        console.log('📱 [JS] Expires:', result.dateExpires);
                        
                        // Send challengeId back to Swift
                        window.webkit.messageHandlers.strigaNative.postMessage({
                            type: 'challengeId',
                            challengeId: result.challengeId,
                            expires: result.dateExpires
                        });
                        
                        return result.challengeId;
                    } catch (error) {
                        console.error('Error requesting consent:', error);
                        window.webkit.messageHandlers.strigaNative.postMessage({ 
                            type: 'error', 
                            message: error.toString() 
                        });
                        throw error;
                    }
                    };
                    
                    // Function 2: Render card details using auth token
                    // Make function available globally on window object
                    window.renderCard = async function(cardId, authToken) {
                    try {
                        console.log('Rendering card:', cardId);
                        
                        // Show card number in secure iframe
                        await StrigaUXPlugin.render('cardNumber', {
                            cardId: cardId,
                            authToken: authToken
                        });
                        
                        // Show CVV in secure iframe
                        await StrigaUXPlugin.render('cvv', {
                            cardId: cardId,
                            authToken: authToken
                        });
                        
                        console.log('Card rendered successfully');
                        
                        // Notify Swift that card is rendered
                        window.webkit.messageHandlers.strigaNative.postMessage({
                            type: 'cardRendered',
                            success: true
                        });
                        
                    } catch (error) {
                        console.error('Error rendering card:', error);
                        window.webkit.messageHandlers.strigaNative.postMessage({ 
                            type: 'error', 
                            message: 'Failed to render card: ' + error.toString() 
                        });
                        throw error;
                    }
                    };
                    
                    // Log when everything is ready
                    console.log('✅ [JS] All functions defined and ready');
                    console.log('📱 [JS] typeof requestConsent:', typeof window.requestConsent);
                    console.log('📱 [JS] Waiting for Swift to call requestConsent()...');
                    
                    // Notify Swift that we're ready
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.strigaNative) {
                        window.webkit.messageHandlers.strigaNative.postMessage({
                            type: 'ready',
                            message: 'Striga initialized and functions ready'
                        });
                    }
                }
                
                // Original code continues here...
                -->
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
        
        // Store reference for later JS calls
        CardConsentWebView.webView = webView
        
        print("📱 [CardConsentWebView] Loading HTML, consent will start when page is ready...")
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // If we have an auth token and should render the card, do it
        if shouldRenderCard, let authToken = authToken, let cardId = cardId {
            let js = "renderCard('\(cardId)', '\(authToken)')"
            uiView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("[CardConsent] Error rendering card: \(error)")
                } else {
                    print("[CardConsent] Card render initiated")
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let parent: CardConsentWebView
        var webView: WKWebView?
        var userId: String = ""
        var hasStartedConsent = false

        init(_ parent: CardConsentWebView) {
            self.parent = parent
        }
        
        // Called when page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ [CardConsentWebView] HTML page finished loading")
            
            // Test if JavaScript is working
            webView.evaluateJavaScript("1 + 1") { result, error in
                if let result = result {
                    print("✅ [CardConsentWebView] JS Engine works: 1 + 1 = \(result)")
                } else if let error = error {
                    print("❌ [CardConsentWebView] JS NOT WORKING: \(error)")
                }
            }
            
            // Check page content
            let debugJS = """
            (function() {
                return {
                    hasBody: document.body ? true : false,
                    scriptCount: document.getElementsByTagName('script').length,
                    bodyHTML: document.body ? document.body.innerHTML.substring(0, 200) : 'NO BODY',
                    hasStriga: typeof StrigaUXPlugin !== 'undefined',
                    readyState: document.readyState
                };
            })()
            """
            
            webView.evaluateJavaScript(debugJS) { result, error in
                if let dict = result as? [String: Any] {
                    print("📊 [CardConsentWebView] Page Debug:")
                    print("  - Has Body: \(dict["hasBody"] ?? false)")
                    print("  - Script Count: \(dict["scriptCount"] ?? 0)")
                    print("  - Has Striga: \(dict["hasStriga"] ?? false)")
                    print("  - Ready State: \(dict["readyState"] ?? "unknown")")
                    print("  - Body HTML: \(dict["bodyHTML"] ?? "empty")")
                }
            }
            
            // Only start consent once
            guard !hasStartedConsent else {
                print("📱 [CardConsentWebView] Consent already started, skipping")
                return
            }
            hasStartedConsent = true
            
            // Wait longer for JS to initialize
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.startConsentFlow(webView: webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ [CardConsentWebView] WebView failed to load: \(error)")
        }
        
        private func startConsentFlow(webView: WKWebView) {
            // Check if requestConsent function exists
            let checkJS = "typeof window.requestConsent !== 'undefined'"
            
            webView.evaluateJavaScript(checkJS) { [weak self] result, error in
                guard let self = self else { return }
                
                if let exists = result as? Bool, exists {
                    print("✅ [CardConsentWebView] JS requestConsent function is ready")
                    
                    // Call requestConsent
                    let js = "requestConsent('\(self.userId)', 'sms')"
                    print("🚀 [CardConsentWebView] Calling requestConsent()")
                    print("📱 [CardConsentWebView] User ID: \(self.userId)")
                    print("📱 [CardConsentWebView] Channel: sms")
                    
                    webView.evaluateJavaScript(js) { result, error in
                        if let error = error {
                            print("❌ [CardConsentWebView] Error calling requestConsent: \(error)")
                            // Try again after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                print("📱 [CardConsentWebView] Retrying requestConsent...")
                                webView.evaluateJavaScript(js) { result, error in
                                    if let error = error {
                                        print("❌ [CardConsentWebView] Retry failed: \(error)")
                                    } else {
                                        print("✅ [CardConsentWebView] Retry successful")
                                    }
                                }
                            }
                        } else {
                            print("✅ [CardConsentWebView] requestConsent() called successfully")
                            print("📱 [CardConsentWebView] Waiting for challengeId from Striga...")
                        }
                    }
                } else {
                    print("❌ [CardConsentWebView] requestConsent function not found!")
                    print("📱 [CardConsentWebView] Retrying in 1 second...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.startConsentFlow(webView: webView)
                    }
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "strigaNative",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            print("[CardConsent] Message from JS: \(type)")

            switch type {
            case "challengeId":
                if let challengeId = body["challengeId"] as? String {
                    print("✅ [CardConsentWebView] SUCCESS: Received challengeId from Striga JS SDK")
                    print("📱 [CardConsentWebView] Challenge ID: \(challengeId)")
                    if let expires = body["expires"] as? String {
                        print("📱 [CardConsentWebView] Challenge expires: \(expires)")
                    }
                    print("📱 [CardConsentWebView] Passing challengeId to parent for OTP flow...")
                    parent.onChallenge(challengeId)
                }
                
            case "cardRendered":
                print("[CardConsent] Card rendered successfully in iframes")
                // Card is now displayed in secure iframes

            case "error":
                let errorMsg = body["message"] as? String ?? "Unknown error"
                print("❌ [CardConsentWebView] ERROR from JS: \(errorMsg)")
                
            case "ready":
                print("✅ [CardConsentWebView] JS signaled ready!")
                if let message = body["message"] as? String {
                    print("📱 [CardConsentWebView] Ready message: \(message)")
                }
                // Start consent flow now that JS is ready
                DispatchQueue.main.async {
                    if let webView = self.webView {
                        self.startConsentFlow(webView: webView)
                    } else {
                        print("❌ [CardConsentWebView] No webView reference in coordinator!")
                    }
                }

            default:
                break
            }
        }
    }
}