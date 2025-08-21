import Foundation

/// Global configuration for network-specific behavior
/// This allows us to easily control what features are available on testnet vs mainnet
struct NetworkConfiguration {
    
    /// Singleton instance
    static let shared = NetworkConfiguration()
    
    private init() {}
    
    /// Current network from UserDefaults
    var currentNetwork: String {
        UserDefaults.standard.string(forKey: "bitcoinNetwork") ?? "testnet3"
    }
    
    /// Check if we're on testnet
    var isTestnet: Bool {
        currentNetwork == "testnet3"
    }
    
    // MARK: - Feature Flags
    // These control what features are available on testnet vs mainnet
    // Change these when ready to enable features on testnet
    
    /// Whether to show real Bitcoin prices on testnet
    /// Set to `true` to show real prices even on testnet (for realistic testing)
    /// Set to `false` to show 0 or mock prices on testnet
    let showRealPricesOnTestnet = true
    
    /// Whether to show the Buy Bitcoin button on testnet
    /// Set to `true` to show the button (it won't actually buy real BTC on testnet)
    /// Set to `false` to hide the button on testnet
    let showBuyButtonOnTestnet = true
    
    /// Whether to allow card operations on testnet
    /// Set to `true` to test card flows with testnet
    /// Set to `false` to disable card features on testnet
    let allowCardOperationsOnTestnet = false
    
    // MARK: - Computed Properties
    
    /// Whether to show real Bitcoin prices
    var shouldShowRealPrices: Bool {
        return !isTestnet || showRealPricesOnTestnet
    }
    
    /// Whether to show the Buy Bitcoin button
    var shouldShowBuyButton: Bool {
        return !isTestnet || showBuyButtonOnTestnet
    }
    
    /// Whether to allow card operations
    var shouldAllowCardOperations: Bool {
        return !isTestnet || allowCardOperationsOnTestnet
    }
    
    /// Get the appropriate exchange rate for display
    func getDisplayExchangeRate(_ realRate: Double) -> Double {
        if shouldShowRealPrices {
            return realRate
        } else {
            // Return 0 or a mock rate for testnet
            return 0.0
        }
    }
    
    /// Get the appropriate Buy button text
    var buyButtonText: String {
        if isTestnet && !showBuyButtonOnTestnet {
            return "" // Hide button
        } else {
            return "+ Buy Bitcoin"
        }
    }
    
    /// Get network display name
    var networkDisplayName: String {
        isTestnet ? "Testnet3" : "Mainnet"
    }
    
    /// Get block explorer URL for a transaction
    func blockExplorerURL(for txId: String) -> String {
        if isTestnet {
            return "https://mempool.space/testnet/tx/\(txId)"
        } else {
            return "https://mempool.space/tx/\(txId)"
        }
    }
}