import SwiftUI
import WebKit
import StrigaAPI

struct CardConsentWebView: UIViewRepresentable {
    let userId: String
    let cardId: String
    let onConsentComplete: (String, String) -> Void // challengeId, dateExpires
    let onError: (String) -> Void
    
    private var uiSecret: String {
        StrigaService.shared.configuration?.uiSecret ?? "YOUR_UI_SECRET"
    }
    
    private var applicationId: String {
        StrigaService.shared.configuration?.applicationId ?? "YOUR_APPLICATION_ID"
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "cardConsent")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Load HTML with Striga UI library
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.striga.com/ui/v1/striga-ui.js"></script>
        </head>
        <body>
            <script>
                // Initialize Striga UI Plugin
                StrigaUXPlugin.create('\(uiSecret)', { 
                    applicationId: '\(applicationId)' 
                });
                
                // Request consent
                async function requestConsent() {
                    try {
                        const response = await StrigaUXPlugin.requestConsent({
                            userId: '\(userId)'
                        });
                        
                        // Send result back to iOS
                        window.webkit.messageHandlers.cardConsent.postMessage({
                            success: true,
                            challengeId: response.challengeId,
                            dateExpires: response.dateExpires
                        });
                    } catch (error) {
                        window.webkit.messageHandlers.cardConsent.postMessage({
                            success: false,
                            error: error.message || error.toString()
                        });
                    }
                }
                
                // Start the consent flow
                requestConsent();
            </script>
            <p>Requesting card verification...</p>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: CardConsentWebView
        
        init(_ parent: CardConsentWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "cardConsent",
                  let body = message.body as? [String: Any],
                  let success = body["success"] as? Bool else { return }
            
            if success,
               let challengeId = body["challengeId"] as? String,
               let dateExpires = body["dateExpires"] as? String {
                parent.onConsentComplete(challengeId, dateExpires)
            } else if let error = body["error"] as? String {
                parent.onError(error)
            }
        }
    }
}