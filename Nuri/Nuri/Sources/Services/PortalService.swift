import Foundation
import PortalSwift
import OSLog  // for simple console logging

/// Thin wrapper around the PortalSwift SDK used by the app.
/// Holds a single `Portal` instance that is initialised with the project's *Client API Key*.
///
/// NOTE: For the first integration step we focus solely on Bitcoin,
/// therefore the RPC configuration is left empty – Portal's backend
/// will default to its own public RPCs. We can override this later
/// if we want to use custom nodes.
final class PortalService {

    // MARK: - Singleton
    static let shared = PortalService()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Nuri", category: "PortalService")
    private init() {
        do {
            portal = try Portal(
                Self.clientAPIKey,
                withRpcConfig: [:],
                autoApprove: true
            )
            log.debug("Portal SDK initialised")
        } catch {
            fatalError("[PortalService] Failed to initialise Portal SDK → \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Creates the MPC wallet if it doesn't exist yet and returns the testnet P2WPKH address.
    @MainActor
    func ensureBitcoinWallet() async throws -> String {
        log.debug("Ensuring BTC wallet…")
        // Attempt to detect an existing wallet first
        if let existingAddress = try? await fetchBitcoinAddress() {
            log.debug("Found existing BTC address: \(existingAddress)")
            return existingAddress
        }

        // Create a fresh wallet (one-time cost)
        log.debug("No BTC address found – invoking createWallet()")
        _ = try await portal.createWallet { [weak self] status in
            self?.log.debug("Portal wallet creation status update: \(status.status.rawValue)")
        }
        return try await fetchBitcoinAddress()
    }

    /// Returns the current BTC address (p2wpkh testnet) of the active Portal wallet.
    func fetchBitcoinAddress() async throws -> String {
        let addresses = try await portal.addresses
        log.debug("Addresses dictionary from SDK: \(addresses)")
        if let btcAddress = addresses.values.compactMap({ $0 }).first(where: { Self.isBitcoinAddress($0) }) {
            return btcAddress
        }
        throw NSError(domain: "PortalService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No Bitcoin address found yet"])
    }

    /// Convenience helper to fetch confirmed + unconfirmed sats for display.
    func fetchBitcoinBalance() async throws -> Int { // returns sats
        return 0 // Placeholder until PortalSwift exposes BTC balances
    }

    // MARK: - Private
    private static let clientAPIKey = "a0eb2a72-47c3-406c-9126-beb5c10ad4e9"
    private let portal: Portal

    // MARK: - Helpers
    private static func isBitcoinAddress(_ address: String) -> Bool {
        // Very naive prefix check for now (test-net + mainnet bech32 or legacy)
        let lower = address.lowercased()
        return lower.hasPrefix("bc1") || lower.hasPrefix("tb1") || lower.hasPrefix("1") || lower.hasPrefix("3")
    }
} 