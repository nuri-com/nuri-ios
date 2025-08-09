import Foundation

public extension StrigaService {
    // ⛔ THIS ENDPOINT DOES NOT EXIST AS REST API ⛔
    // 
    // request-consent is ONLY available as a JavaScript SDK method:
    //   StrigaUXPlugin.requestConsent({ userId })
    //
    // It must be called from within a WebView context with Striga's JS SDK loaded.
    //
    // For iOS native apps, use one of these approaches:
    // 1. Hosted Card UI: Call startHostedCardSession() and open WebView
    // 2. Custom WebView: Load your own HTML with Striga JS SDK
    //
    // This function will ALWAYS timeout because the endpoint doesn't exist!
    //
    @available(*, deprecated, message: "DOES NOT EXIST! Use Hosted Card UI - request-consent is JavaScript-only")
    func requestConsent(_ input: RequestConsent) async throws -> RequestConsentResponse {
        print("⛔ FATAL: Calling non-existent endpoint /api/v1/card/request-consent")
        print("This will timeout after 120 seconds because the endpoint doesn't exist!")
        print("Use startHostedCardSession() instead for iOS apps")
        
        let url = try self.url(for: "v1/card/request-consent")
        return try await self.httpClient.post(url: url, input: input)
    }
}