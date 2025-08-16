import Foundation
import BitcoinDevKit

/// Wrapper for EsploraClient that adds Blockstream authentication
final class AuthenticatedEsploraClient {
    private let authManager = BlockstreamAuthManager.shared
    private let baseClient: EsploraClient
    
    init() {
        // Initialize with the authenticated base URL
        self.baseClient = EsploraClient(url: BlockstreamAuthManager.shared.authenticatedBaseURL)
        print("🔐 [AuthenticatedEsplora] Initialized with enterprise endpoint")
    }
    
    /// Get the underlying EsploraClient
    /// Note: For now, we're using the standard EsploraClient which doesn't support custom headers
    /// We'll need to implement a custom solution or wait for BDK to support authentication
    func getClient() -> EsploraClient {
        return baseClient
    }
    
    /// Make authenticated API request (for custom endpoints)
    func makeAuthenticatedRequest(endpoint: String) async throws -> Data {
        let authHeader = try await authManager.getAuthorizationHeader()
        let urlString = "\(authManager.authenticatedBaseURL)/\(endpoint)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
}

// MARK: - Extension for BitcoinWalletService compatibility

extension AuthenticatedEsploraClient {
    /// Helper to check if we should use authentication
    /// For now, we'll use the public API until we can properly integrate auth with BDK
    static func shouldUseAuthentication() -> Bool {
        // TODO: Enable this once we figure out how to pass auth headers to BDK's EsploraClient
        // For now, return false to keep using public API
        return false
    }
    
    /// Get the appropriate Esplora client based on configuration
    static func createClient(network: Network? = nil) -> EsploraClient {
        // Determine network - if not specified, read from UserDefaults
        let actualNetwork: Network
        if let network = network {
            actualNetwork = network
        } else {
            let networkString = UserDefaults.standard.string(forKey: "bitcoinNetwork") ?? "testnet3"
            actualNetwork = networkString == "testnet3" ? .testnet : .bitcoin
        }
        
        if shouldUseAuthentication() {
            print("🔐 [AuthenticatedEsplora] Using authenticated enterprise endpoint")
            return EsploraClient(url: BlockstreamAuthManager.shared.authenticatedBaseURL)
        } else {
            let url = actualNetwork == .testnet ? 
                "https://blockstream.info/testnet/api" : 
                "https://blockstream.info/api"
            print("📡 [AuthenticatedEsplora] Using public API endpoint for \(actualNetwork == .testnet ? "testnet3" : "mainnet"): \(url)")
            return EsploraClient(url: url)
        }
    }
}