import Foundation
import StrigaAPI

/// Service responsible for synchronizing Striga user data after authentication
/// Ensures correct user IDs, wallet IDs, and card IDs are fetched and stored
@MainActor
class StrigaSyncService {
    
    static let shared = StrigaSyncService()
    
    private init() {}
    
    /// Synchronizes all Striga data for the authenticated user
    /// - Parameter userId: The Striga user ID to sync data for
    /// - Returns: True if sync was successful, false otherwise
    func syncUserData(userId: String) async -> Bool {
        print("[StrigaSyncService] Starting sync for user: \(userId)")
        
        // Clear any old cached data first to prevent conflicts
        clearCachedData()
        
        do {
            // Store the user ID
            var settings = UserSettings()
            settings.strigaUserId = userId
            StrigaSession.shared.userId = userId
            
            // Fetch user's wallets
            let walletsResponse = try await StrigaService.shared.getWallets(userId: userId)
            print("[StrigaSyncService] Found \(walletsResponse.wallets.count) wallet(s) for user")
            
            guard let firstWallet = walletsResponse.wallets.first else {
                print("[StrigaSyncService] No wallets found for user")
                return false
            }
            
            // Verify ownership
            guard firstWallet.syncedOwnerId == userId else {
                print("[StrigaSyncService] ERROR: Wallet owner mismatch! Wallet owner: \(firstWallet.syncedOwnerId), User: \(userId)")
                return false
            }
            
            // Store wallet ID
            settings.strigaWalletId = firstWallet.walletId
            print("[StrigaSyncService] Stored wallet ID: \(firstWallet.walletId)")
            
            // Find linked card from wallet accounts
            var foundCardId: String?
            
            // Check EUR account for linked card (most common)
            if let eurAccount = firstWallet.accounts.eur,
               let linkedCardId = eurAccount.linkedCardId {
                foundCardId = linkedCardId
                print("[StrigaSyncService] Found card linked to EUR account: \(linkedCardId)")
            }
            
            // If no card in EUR, check other accounts
            if foundCardId == nil {
                let accounts = [
                    firstWallet.accounts.btc,
                    firstWallet.accounts.eth,
                    firstWallet.accounts.usdc,
                    firstWallet.accounts.usdt
                ].compactMap { $0 }
                
                for account in accounts {
                    if let linkedCardId = account.linkedCardId {
                        foundCardId = linkedCardId
                        print("[StrigaSyncService] Found card linked to \(account.currency) account: \(linkedCardId)")
                        break
                    }
                }
            }
            
            // Verify and store card if found
            if let cardId = foundCardId {
                // Verify the card exists and belongs to this user
                do {
                    let cardResponse = try await StrigaService.shared.getCard(.init(
                        userId: userId,
                        cardId: cardId,
                        authToken: nil
                    ))
                    
                    // Verify card ownership
                    guard cardResponse.userId == userId else {
                        print("[StrigaSyncService] ERROR: Card owner mismatch! Card owner: \(cardResponse.userId), User: \(userId)")
                        return false
                    }
                    
                    // Store card ID
                    settings.strigaCardId = cardId
                    StrigaSession.shared.cardId = cardId
                    print("[StrigaSyncService] Successfully verified and stored card: \(cardId)")
                    print("[StrigaSyncService] Card status: \(cardResponse.status)")
                    
                } catch {
                    print("[StrigaSyncService] Failed to verify card \(cardId): \(error)")
                    // Don't store invalid card ID
                }
            } else {
                print("[StrigaSyncService] No card found for user's wallets")
            }
            
            print("[StrigaSyncService] ✅ Sync completed successfully")
            print("[StrigaSyncService] - User ID: \(userId)")
            print("[StrigaSyncService] - Wallet ID: \(firstWallet.walletId)")
            print("[StrigaSyncService] - Card ID: \(foundCardId ?? "none")")
            
            return true
            
        } catch {
            print("[StrigaSyncService] ❌ Sync failed: \(error)")
            return false
        }
    }
    
    /// Clears all cached Striga IDs to prevent conflicts
    private func clearCachedData() {
        print("[StrigaSyncService] Clearing cached Striga data")
        
        var settings = UserSettings()
        
        // Clear old IDs
        let oldUserId = settings.strigaUserId
        let oldCardId = settings.strigaCardId
        let oldWalletId = settings.strigaWalletId
        
        settings.strigaUserId = nil
        settings.strigaCardId = nil
        settings.strigaWalletId = nil
        
        StrigaSession.shared.userId = nil
        StrigaSession.shared.cardId = nil
        
        if oldUserId != nil || oldCardId != nil || oldWalletId != nil {
            print("[StrigaSyncService] Cleared old cached data:")
            print("  - Old User ID: \(oldUserId ?? "none")")
            print("  - Old Card ID: \(oldCardId ?? "none")")
            print("  - Old Wallet ID: \(oldWalletId ?? "none")")
        }
    }
    
    /// Validates that the current cached IDs are still valid and belong to the same user
    func validateCachedData() async -> Bool {
        let settings = UserSettings()
        
        guard let userId = settings.strigaUserId,
              let walletId = settings.strigaWalletId else {
            print("[StrigaSyncService] No cached data to validate")
            return false
        }
        
        do {
            // Verify wallet still exists and belongs to user
            let walletsResponse = try await StrigaService.shared.getWallets(userId: userId)
            
            guard walletsResponse.wallets.contains(where: { $0.walletId == walletId && $0.syncedOwnerId == userId }) else {
                print("[StrigaSyncService] Cached wallet no longer valid")
                return false
            }
            
            // Verify card if present
            if let cardId = settings.strigaCardId {
                do {
                    let cardResponse = try await StrigaService.shared.getCard(.init(
                        userId: userId,
                        cardId: cardId,
                        authToken: nil
                    ))
                    
                    guard cardResponse.userId == userId else {
                        print("[StrigaSyncService] Cached card no longer belongs to user")
                        return false
                    }
                } catch {
                    print("[StrigaSyncService] Cached card no longer valid: \(error)")
                    return false
                }
            }
            
            print("[StrigaSyncService] ✅ Cached data is valid")
            return true
            
        } catch {
            print("[StrigaSyncService] Failed to validate cached data: \(error)")
            return false
        }
    }
}