import Foundation
import WebKit
import UIKit

/// Presents a lightweight WKWebView that runs the (JS) Privy passkey helper that we bundle in `privy-passkey.html`.
/// When the JS side calls `window.webkit.messageHandlers.privy.postMessage(...)` we forward either a
/// .success or .failure back to the caller.
final class PrivyPasskeyWebViewController: UIViewController, WKScriptMessageHandler {
    enum Result {
        case success
        case failure(Error)
        case cancelled
    }

    private var completion: ((Result) -> Void)?

    static func present(over parent: UIViewController,
                        completion: @escaping (Result) -> Void) {
        let vc = PrivyPasskeyWebViewController()
        vc.completion = completion

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        parent.present(nav, animated: true)
    }

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Passkey Login"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

        let contentController = WKUserContentController()
        contentController.add(self, name: "privy")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadEmbeddedHTML()
    }

    private func loadEmbeddedHTML() {
        let html = """
        <!doctype html>
        <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
        <title>Passkey</title></head><body>
        <script src='https://cdn.privy.io/browser-auth/v0.50/privy.iife.js'></script>
        <script>
        (async function(){
          const APP_ID='cmaz6gvx500zykw0lfnlv4lrb';
          const CLIENT_ID='client-WY6LLkqWnXYc7pzZRgxosYUCiSHddSsfUaYnW2E9rA1rV';
          const RP='https://nuri.com';
          try {
            const privy=window.Privy.createPrivyClient({appId:APP_ID,clientId:CLIENT_ID,loginMethods:['passkey']});
            await privy.loginWithPasskey({relyingParty:RP});
            window.webkit.messageHandlers.privy.postMessage('success');
          } catch(e){
            window.webkit.messageHandlers.privy.postMessage('error:'+e.message);
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
        guard message.name == "privy" else { return }
        guard let body = message.body as? String else { return }
        if body == "success" {
            completion?(.success)
        } else if body.hasPrefix("error:") {
            let msg = body.replacingOccurrences(of: "error:", with: "")
            completion?(.failure(NSError(domain: "Passkey", code: -2, userInfo: [NSLocalizedDescriptionKey: msg])))
        }
        dismiss(animated: true)
    }
} 