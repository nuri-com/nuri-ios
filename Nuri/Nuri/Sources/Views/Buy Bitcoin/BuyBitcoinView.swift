import SwiftUI
import WebKit

struct BuyBitcoinWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        if let url = URL(string: "https://exchange.mercuryo.io/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ Mercuryo exchange loaded")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ Failed to load Mercuryo: \(error)")
        }
    }
}

struct BuyBitcoinView: View {
    @EnvironmentObject var navigation: BitcoinViewNavigation
    
    var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>.logo(
                title: "Buy Bitcoin",
                onClose: { navigation.isBuyViewPresented = false }
            )
            
            BuyBitcoinWebView()
        }
        .background(NuriAsset.background.swiftUIColor)
    }
}

#Preview {
    BuyBitcoinView()
        .environmentObject(BitcoinViewNavigation())
}