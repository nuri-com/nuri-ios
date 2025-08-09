import SwiftUI
import WebKit

// MARK: - Bridge for WebView communication
final class StrigaBridge: NSObject, WKScriptMessageHandler {
    var onChallenge: ((String) -> Void)?
    var onRendered: (() -> Void)?
    var onError: ((String) -> Void)?
    var onLog: ((String) -> Void)?

    func userContentController(_ uc: WKUserContentController, didReceive m: WKScriptMessage) {
        guard m.name == "strigaNative",
              let dict = m.body as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        switch type {
        case "challenge":
            if let data = dict["data"] as? [String: Any],
               let challengeId = data["challengeId"] as? String {
                print("✅ [StrigaBridge] Received challengeId: \(challengeId)")
                onChallenge?(challengeId)
            }
        case "rendered":
            print("✅ [StrigaBridge] Card rendered successfully")
            onRendered?()
        case "error":
            let error = dict["data"] as? String ?? "Unknown error"
            print("❌ [StrigaBridge] Error: \(error)")
            onError?(error)
        case "log":
            let message = dict["data"] as? String ?? ""
            print("📱 [StrigaBridge JS]: \(message)")
            onLog?(message)
        default:
            break
        }
    }
}

// MARK: - WebView Component
struct StrigaCardWebView: UIViewRepresentable {
    let uiSecret: String
    let applicationId: String
    let userId: String
    let bridge: StrigaBridge
    
    @Binding var webViewRef: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        print("🚀 [StrigaCardWebView] Creating WebView")
        print("📱 [StrigaCardWebView] User ID: \(userId)")
        print("📱 [StrigaCardWebView] App ID: \(applicationId)")
        
        let cfg = WKWebViewConfiguration()
        cfg.preferences.javaScriptEnabled = true
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        
        // Allow loading external scripts
        if #available(iOS 14.0, *) {
            cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Allow arbitrary loads for external scripts
        cfg.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        if cfg.preferences.responds(to: Selector("setJavaScriptCanOpenWindowsAutomatically:")) {
            cfg.preferences.javaScriptCanOpenWindowsAutomatically = false
        }
        
        cfg.userContentController.add(bridge, name: "strigaNative")
        
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        
        // Load from file for better external script support
        if let htmlPath = Bundle.main.path(forResource: "striga_card_display", ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath).deletingLastPathComponent()
            
            // Load HTML file
            wv.loadFileURL(URL(fileURLWithPath: htmlPath), allowingReadAccessTo: htmlURL)
            
            // Set navigation delegate to initialize after load
            wv.navigationDelegate = context.coordinator
        } else {
            // Fallback: try original file name
            if let htmlPath = Bundle.main.path(forResource: "striga_card", ofType: "html") {
                let htmlURL = URL(fileURLWithPath: htmlPath).deletingLastPathComponent()
                print("⚠️ [StrigaCardWebView] Using striga_card.html as fallback")
                wv.loadFileURL(URL(fileURLWithPath: htmlPath), allowingReadAccessTo: htmlURL)
                wv.navigationDelegate = context.coordinator
            } else {
                // No HTML files found
                print("❌ [StrigaCardWebView] ERROR: No HTML resource files found")
                print("❌ [StrigaCardWebView] Please ensure striga_loader.html or striga_card.html is in Resources")
            }
        }
        DispatchQueue.main.async { 
            webViewRef = wv
            print("✅ [StrigaCardWebView] WebView reference stored")
        }
        return wv
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: StrigaCardWebView
        
        init(_ parent: StrigaCardWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("🌐 [StrigaCardWebView] Page loaded, initializing Striga...")
            
            // Initialize Striga SDK
            let initJS = "initStriga('\(parent.uiSecret)', '\(parent.applicationId)')"
            webView.evaluateJavaScript(initJS) { result, error in
                if let error = error {
                    print("❌ [StrigaCardWebView] Failed to init Striga: \(error)")
                } else {
                    print("✅ [StrigaCardWebView] initStriga called, result: \(String(describing: result))")
                }
            }
        }
    }
}

// MARK: - WebView Extensions
extension WKWebView {
    func strigaRequestConsent(userId: String, channel: String? = nil) {
        print("🚀 [WKWebView] Calling requestConsent")
        print("📱 [WKWebView] userId: \(userId), channel: \(channel ?? "both")")
        
        let ch = (channel != nil) ? "'\(channel!)'" : "undefined"
        let js = "requestConsent('\(userId)', \(ch));"
        
        evaluateJavaScript(js) { result, error in
            if let error = error {
                print("❌ [WKWebView] Error calling requestConsent: \(error)")
            } else {
                print("✅ [WKWebView] requestConsent called successfully")
            }
        }
    }
    
    func strigaRender(cardId: String, authToken: String) {
        print("🚀 [WKWebView] Calling renderCard")
        print("📱 [WKWebView] cardId: \(cardId)")
        print("🔑 [WKWebView] authToken length: \(authToken.count)")
        print("🔑 [WKWebView] authToken preview: \(String(authToken.prefix(50)))...")
        
        let js = "renderCard('\(cardId)','\(authToken)');"
        print("📝 [WKWebView] JavaScript call: renderCard('\(cardId)','\(String(authToken.prefix(20)))...')")
        
        evaluateJavaScript(js) { result, error in
            if let error = error {
                print("❌ [WKWebView] Error calling renderCard: \(error)")
            } else {
                print("✅ [WKWebView] renderCard called successfully")
            }
        }
    }
}