import Foundation
import PortalSwift

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
    private init() {
        do {
            portal = try Portal(
                Self.clientAPIKey,
                withRpcConfig: [:],
                autoApprove: true
            )
        } catch {
            fatalError("[PortalService] Failed to initialise Portal SDK → \(error)")
        }
    }

    // MARK: - Public API

    /// Creates the MPC wallet if it doesn't exist yet and returns the testnet P2WPKH address.
    @MainActor
    func ensureBitcoinWallet() async throws -> String {
        // Attempt to detect an existing wallet first
        if let existingAddress = try? await fetchBitcoinAddress() {
            return existingAddress
        }

        // Create a fresh wallet (one-time cost)
        _ = try await portal.createWallet { status in
            #if DEBUG
            print("[Portal] wallet creation status →", status.status)
            #endif
        }
        return try await fetchBitcoinAddress()
    }

    /// Returns the current BTC address (p2wpkh testnet) of the active Portal wallet.
    func fetchBitcoinAddress() async throws -> String {
        let addresses = try await portal.addresses
        if let anyAddress = addresses.values.compactMap({ $0 }).first {
            return anyAddress
        }
        throw NSError(domain: "PortalService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No address found"])
    }

    /// Convenience helper to fetch confirmed + unconfirmed sats for display.
    func fetchBitcoinBalance() async throws -> Int { // returns sats
        return 0 // Placeholder until PortalSwift exposes BTC balances
    }

    // MARK: - Private
    private static let clientAPIKey = "a0eb2a72-47c3-406c-9126-beb5c10ad4e9"
    private let portal: Portal
} 