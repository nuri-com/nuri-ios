import Foundation

/// Direct Blockstream API client with authentication support
/// This supplements BDK's EsploraClient for operations that need authentication
final class BlockstreamAPIClient {
    static let shared = BlockstreamAPIClient()
    private let authManager = BlockstreamAuthManager.shared
    
    private init() {}
    
    // MARK: - Configuration
    
    private var baseURL: String {
        // Use authenticated endpoint when available, fallback to public
        if BlockstreamAPIClient.useAuthentication {
            return authManager.authenticatedBaseURL
        } else {
            return "https://blockstream.info/api"
        }
    }
    
    /// Flag to enable/disable authentication
    static var useAuthentication: Bool = true
    
    // MARK: - API Methods
    
    /// Fetch address info with authentication
    func getAddressInfo(address: String) async throws -> BlockstreamAddressInfo {
        let endpoint = "address/\(address)"
        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder().decode(BlockstreamAddressInfo.self, from: data)
    }
    
    /// Fetch address UTXOs with authentication
    func getAddressUTXOs(address: String) async throws -> [UTXO] {
        let endpoint = "address/\(address)/utxo"
        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder().decode([UTXO].self, from: data)
    }
    
    /// Fetch address transactions with authentication
    func getAddressTransactions(address: String) async throws -> [BlockstreamTransaction] {
        let endpoint = "address/\(address)/txs"
        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder().decode([BlockstreamTransaction].self, from: data)
    }
    
    /// Broadcast transaction with authentication
    func broadcastTransaction(txHex: String) async throws -> String {
        let endpoint = "tx"
        let data = try await makeRequest(endpoint: endpoint, method: "POST", body: txHex)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Get current fee estimates with authentication
    func getFeeEstimates() async throws -> FeeEstimates {
        let endpoint = "fee-estimates"
        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder().decode(FeeEstimates.self, from: data)
    }
    
    // MARK: - Private Methods
    
    private func makeRequest(endpoint: String, method: String = "GET", body: String? = nil) async throws -> Data {
        let urlString = "\(baseURL)/\(endpoint)"
        
        guard let url = URL(string: urlString) else {
            throw BlockstreamAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add authentication if enabled
        if BlockstreamAPIClient.useAuthentication {
            do {
                let authHeader = try await authManager.getAuthorizationHeader()
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
                print("🔐 [BlockstreamAPI] Making authenticated request to: \(endpoint)")
            } catch {
                print("⚠️ [BlockstreamAPI] Failed to get auth token, falling back to public API: \(error)")
                // Continue without authentication
            }
        } else {
            print("📡 [BlockstreamAPI] Making public request to: \(endpoint)")
        }
        
        if let body = body {
            request.httpBody = body.data(using: .utf8)
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BlockstreamAPIError.invalidResponse
            }
            
            // Check for rate limiting
            if httpResponse.statusCode == 429 {
                print("⚠️ [BlockstreamAPI] Rate limited! Status: 429")
                throw BlockstreamAPIError.rateLimited
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [BlockstreamAPI] Request failed with status: \(httpResponse.statusCode)")
                throw BlockstreamAPIError.requestFailed(statusCode: httpResponse.statusCode)
            }
            
            return data
            
        } catch {
            print("❌ [BlockstreamAPI] Request failed: \(error)")
            throw error
        }
    }
}

// MARK: - Data Models

struct BlockstreamAddressInfo: Codable {
    let address: String
    let chain_stats: ChainStats
    let mempool_stats: MempoolStats
    
    struct ChainStats: Codable {
        let funded_txo_count: Int
        let funded_txo_sum: Int64
        let spent_txo_count: Int
        let spent_txo_sum: Int64
        let tx_count: Int
    }
    
    struct MempoolStats: Codable {
        let funded_txo_count: Int
        let funded_txo_sum: Int64
        let spent_txo_count: Int
        let spent_txo_sum: Int64
        let tx_count: Int
    }
    
    var balance: Int64 {
        let confirmed = chain_stats.funded_txo_sum - chain_stats.spent_txo_sum
        let pending = mempool_stats.funded_txo_sum - mempool_stats.spent_txo_sum
        return confirmed + pending
    }
    
    var confirmedBalance: Int64 {
        return chain_stats.funded_txo_sum - chain_stats.spent_txo_sum
    }
    
    var pendingBalance: Int64 {
        return mempool_stats.funded_txo_sum - mempool_stats.spent_txo_sum
    }
}

struct UTXO: Codable {
    let txid: String
    let vout: Int
    let status: Status
    let value: Int64
    
    struct Status: Codable {
        let confirmed: Bool
        let block_height: Int?
        let block_hash: String?
        let block_time: Int64?
    }
}

struct BlockstreamTransaction: Codable {
    let txid: String
    let version: Int
    let locktime: Int
    let vin: [Input]
    let vout: [Output]
    let size: Int
    let weight: Int
    let fee: Int64?
    let status: Status
    
    struct Input: Codable {
        let txid: String
        let vout: Int
        let prevout: Output?
        let scriptsig: String
        let scriptsig_asm: String
        let witness: [String]?
        let is_coinbase: Bool
        let sequence: Int64
    }
    
    struct Output: Codable {
        let scriptpubkey: String
        let scriptpubkey_asm: String
        let scriptpubkey_type: String
        let scriptpubkey_address: String?
        let value: Int64
    }
    
    struct Status: Codable {
        let confirmed: Bool
        let block_height: Int?
        let block_hash: String?
        let block_time: Int64?
    }
}

struct FeeEstimates: Codable {
    let estimates: [String: Double] // Block target -> fee rate in sat/vB
    
    private enum CodingKeys: String, CodingKey {
        case estimates = ""
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.estimates = try container.decode([String: Double].self)
    }
    
    var fastestFee: Int {
        Int(estimates["1"] ?? 5)
    }
    
    var halfHourFee: Int {
        Int(estimates["3"] ?? 3)
    }
    
    var hourFee: Int {
        Int(estimates["6"] ?? 2)
    }
    
    var economyFee: Int {
        Int(estimates["144"] ?? 1)
    }
}

// MARK: - Error Types

enum BlockstreamAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimited
    case requestFailed(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .rateLimited:
            return "API rate limit exceeded"
        case .requestFailed(let statusCode):
            return "API request failed with status code: \(statusCode)"
        }
    }
}