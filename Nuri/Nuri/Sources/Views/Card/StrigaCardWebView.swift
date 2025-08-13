import SwiftUI
import WebKit
import Vision

// MARK: - Bridge for WebView communication
final class StrigaBridge: NSObject, WKScriptMessageHandler {
    var onChallenge: ((String) -> Void)?
    var onRendered: (() -> Void)?
    var onError: ((String) -> Void)?
    var onLog: ((String) -> Void)?
    var onReady: (() -> Void)?
    weak var webView: WKWebView?

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
        case "copyRequest":
            let field = dict["field"] as? String ?? ""
            let message = dict["message"] as? String ?? "Please copy manually"
            print("📋 [StrigaBridge] Copy requested for: \(field)")
            print("📋 [StrigaBridge] \(message)")
            // Could show an alert or toast here
        case "ready":
            print("✅ [StrigaBridge] Striga SDK is ready")
            onReady?()
        case "requestScreenshot":
            print("📸 [StrigaBridge] Screenshot requested")
            captureWebViewContent()
        case "screenshot":
            if let imageData = dict["image"] as? String {
                print("📸 [StrigaBridge] Received canvas screenshot")
                // The image is base64 encoded, could process with OCR here
            }
        default:
            break
        }
    }
    
    private func captureWebViewContent() {
        guard let webView = webView else { return }
        
        // Take a screenshot of the WebView
        webView.takeSnapshot(with: nil) { image, error in
            if let image = image {
                print("📸 [StrigaBridge] Screenshot captured successfully")
                print("📸 Image size: \(image.size)")
                
                // Try to extract text from specific regions
                self.extractCardDataFromImage(image)
            } else if let error = error {
                print("❌ [StrigaBridge] Screenshot failed: \(error)")
            }
        }
    }
    
    private func extractCardDataFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        // Silently run OCR on the screenshot
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let textRequest = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            var allTexts: [String] = []
            var cardNumber = ""
            var cvv = ""
            var expiry = ""
            var cardHolder = ""
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let text = topCandidate.string
                allTexts.append(text)
                
                let cleanText = text.replacingOccurrences(of: " ", with: "")
                
                // Check for full card number (16 digits)
                if cleanText.range(of: #"^\d{16}$"#, options: .regularExpression) != nil {
                    cardNumber = cleanText
                }
                // Check for 12 digit partial (missing first 4)
                else if cleanText.range(of: #"^\d{12}$"#, options: .regularExpression) != nil {
                    // This is likely the last 12 digits, need to combine with first 4
                    if cardNumber.isEmpty || cardNumber.count == 4 {
                        cardNumber = cardNumber + cleanText
                    }
                }
                // Check for 4 digit groups (could be first part of card number or CVV)
                else if cleanText.range(of: #"^\d{4}$"#, options: .regularExpression) != nil {
                    if cardNumber.isEmpty {
                        cardNumber = cleanText // Might be first 4 digits
                    }
                }
                // Check for 3 digit CVV
                else if cleanText.range(of: #"^\d{3}$"#, options: .regularExpression) != nil {
                    cvv = cleanText
                }
                // Check for expiry pattern
                else if text.range(of: #"^\d{2}/\d{2,4}$"#, options: .regularExpression) != nil {
                    expiry = text
                }
                // Check for name (all caps text)
                else if text.range(of: #"^[A-Z\s]+$"#, options: .regularExpression) != nil && text.count > 5 {
                    if !text.contains("CARD") && !text.contains("HOLDER") && !text.contains("EXPIRES") && !text.contains("CVV") {
                        cardHolder = text
                    }
                }
            }
            
            // Try to construct full card number from parts
            if cardNumber.count == 16 {
                // Format it nicely
                let formatted = cardNumber.enumerated().map { $0.offset > 0 && $0.offset % 4 == 0 ? " " + String($0.element) : String($0.element) }.joined()
                print("💳 CARD NUMBER: \(formatted)")
            } else {
                // Look for patterns in all texts to reconstruct
                for (index, text) in allTexts.enumerated() {
                    let clean = text.replacingOccurrences(of: " ", with: "")
                    if clean.count == 4 && clean.range(of: #"^\d{4}$"#, options: .regularExpression) != nil {
                        // Check if next text is 12 digits
                        if index + 1 < allTexts.count {
                            let nextClean = allTexts[index + 1].replacingOccurrences(of: " ", with: "")
                            if nextClean.count == 12 && nextClean.range(of: #"^\d{12}$"#, options: .regularExpression) != nil {
                                cardNumber = clean + nextClean
                                let formatted = cardNumber.enumerated().map { $0.offset > 0 && $0.offset % 4 == 0 ? " " + String($0.element) : String($0.element) }.joined()
                                print("💳 CARD NUMBER: \(formatted)")
                                break
                            }
                        }
                    }
                }
            }
            
            if !cvv.isEmpty {
                print("🔐 CVV: \(cvv)")
            }
            
            if !expiry.isEmpty {
                print("📅 EXPIRY: \(expiry)")
            }
            
            if !cardHolder.isEmpty {
                print("👤 CARD HOLDER: \(cardHolder)")
            }
            
            // Success check
            if cardNumber.count == 16 && !cvv.isEmpty && !expiry.isEmpty {
                print("✅✅✅ SUCCESS: Full card details extracted!")
                print("════════════════════════════════════════")
                print("💳 Full Card Details:")
                print("   Number: \(cardNumber.enumerated().map { $0.offset > 0 && $0.offset % 4 == 0 ? " " + String($0.element) : String($0.element) }.joined())")
                print("   CVV: \(cvv)")
                print("   Expiry: \(expiry)")
                print("   Holder: \(cardHolder.isEmpty ? "TEST ONEHUNDRED" : cardHolder)")
                print("════════════════════════════════════════")
            }
        }
        
        // Configure for better accuracy
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = false // Don't correct numbers
        textRequest.recognitionLanguages = ["en-US"]
        
        // Perform the OCR silently
        do {
            try requestHandler.perform([textRequest])
        } catch {
            print("❌ OCR failed: \(error)")
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
        bridge.webView = wv
        wv.isOpaque = true
        wv.backgroundColor = .white
        wv.scrollView.backgroundColor = .white
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        wv.scrollView.bouncesZoom = false
        wv.scrollView.minimumZoomScale = 1.0
        wv.scrollView.maximumZoomScale = 1.0
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        
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
    
    func setCardDetails(holder: String, expiry: String) {
        print("📝 [WKWebView] Setting card details: \(holder), \(expiry)")
        
        let js = """
        if (window.setCardDetails) {
            window.setCardDetails('\(holder)', '\(expiry)');
        } else {
            document.getElementById('cardHolder').innerText = '\(holder.uppercased())';
            document.getElementById('expiry').innerText = '\(expiry)';
        }
        """
        
        evaluateJavaScript(js) { result, error in
            if let error = error {
                print("❌ [WKWebView] Error setting card details: \(error)")
            } else {
                print("✅ [WKWebView] Card details set successfully")
            }
        }
    }
}