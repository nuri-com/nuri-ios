import Foundation
import PrivySDK

enum PrivyManager {
    // Replace with your real values from Privy dashboard
    static let appId = "cmaz6gvx500zykw0lfnlv4lrb"
    static let clientId = "client-WY6LLkqWnXYc7pzZRgxosYUCiSHddSsfUaYnW2E9rA1rV"

    static let shared: Privy = {
        let config = PrivyConfig(
            appId: appId,
            appClientId: clientId,
            loggingConfig: .init(logLevel: .verbose)
        )
        let sdk = PrivySdk.initialize(config: config)
        print("📦 [Privy] currentUser:", sdk.user?.id ?? "nil")
        return sdk
    }()

    static var currentUser: PrivyUser? {
        shared.user
    }
} 