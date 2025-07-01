import Foundation
import WebKit
import UIKit

/// Presents a lightweight WKWebView that runs the (JS) Privy passkey helper that we bundle in `privy-passkey.html`.
/// When the JS side calls `window.webkit.messageHandlers.privy.postMessage(...)` we forward either a
/// .success or .failure back to the caller.
final class PrivyPasskeyWebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    enum Result {
        case success(String)
        case failure(Error)
        case cancelled
    }

    private var completion: ((Result) -> Void)?
    private var webView: WKWebView!
    var onAuthComplete: ((String) -> Void)?
    var onWebViewReady: (() -> Void)?
    var onBitcoinWalletCreated: (([String: Any]) -> Void)?
    
    private let privyAppId = PrivyManager.appId
    private let baseURL = "https://auth.privy.io"

    static func present(over parent: UIViewController,
                        completion: @escaping (Result) -> Void) {
        let vc = PrivyPasskeyWebViewController()
        vc.completion = completion

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        parent.present(nav, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign In with Passkey"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

        setupWebView()
        loadPrivyAuthPage()
    }

    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "privy")
        contentController.add(self, name: "privyBitcoinWallet")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadPrivyAuthPage() {
        // Update these with the actual Privy credentials
        let appId = PrivyManager.appId
        let clientId = PrivyManager.clientId
        let relyingParty = "https://nuri.com"
        
        print("🌐 [PrivyPasskeyWebViewController] Loading web passkey with appId: \(appId)")
        
        let html = """
        <!doctype html>
        <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
        <title>Passkey Authentication</title>
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                display: flex; 
                justify-content: center; 
                align-items: center; 
                height: 100vh; 
                margin: 0; 
                background: #f6f6f6;
            }
            .loading { font-size: 18px; color: #333; }
        </style>
        </head><body>
        <div class="loading">Authenticating with passkey...</div>
        <script src='https://cdn.privy.io/browser-auth/v0.50/privy.iife.js'></script>
        <script>
        (async function(){
          const APP_ID='\(appId)';
          const CLIENT_ID='\(clientId)';
          const RP='\(relyingParty)';
          
          console.log('Starting Privy passkey auth...');
          
          try {
            const privy = window.Privy.createPrivyClient({
              appId: APP_ID,
              clientId: CLIENT_ID,
              loginMethods: ['passkey']
            });
            
            console.log('Privy client created, attempting login...');
            
            // This will handle both registration and login automatically
            await privy.loginWithPasskey({relyingParty: RP});
            
            console.log('Passkey authentication successful!');
            window.webkit.messageHandlers.privy.postMessage('success');
          } catch(e) {
            console.error('Passkey authentication failed:', e);
            window.webkit.messageHandlers.privy.postMessage('error:' + (e.message || 'Unknown error'));
          }
        })();
        </script></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    @objc private func cancel() {
        completion?(.cancelled)
        dismiss(animated: true)
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("📨 [PrivyPasskeyWebViewController] Received message: \(message.name)")
        
        switch message.name {
        case "privy", "privyAuth":
            // Handle authentication messages
            if let dict = message.body as? [String: Any],
               let type = dict["type"] as? String {
                print("   📍 Message type: \(type)")
                
                if type == "success",
                   let data = dict["data"] as? [String: Any],
                   let accessToken = data["access_token"] as? String {
                    print("   ✅ Received access token: \(accessToken.prefix(20))...")
                    onAuthComplete?(accessToken)
                    completion?(.success(accessToken))
                    dismiss(animated: true)
                } else if type == "error" {
                    let error = dict["error"] as? String ?? "Unknown error"
                    print("   ❌ Error: \(error)")
                    completion?(.failure(NSError(domain: "PrivyPasskey", code: -1, 
                                               userInfo: [NSLocalizedDescriptionKey: error])))
                    dismiss(animated: true)
                }
            }
            
        case "privyBitcoinWallet":
            // Handle Bitcoin wallet creation messages
            if let result = message.body as? [String: Any] {
                print("   📍 Bitcoin wallet result: \(result)")
                onBitcoinWalletCreated?(result)
                dismiss(animated: true)
            }
            
        default:
            print("   ⚠️ Unknown message handler: \(message.name)")
        }
    }

    // Add a method to evaluate JavaScript
    func evaluateJavaScript(_ script: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: completionHandler)
    }
} 