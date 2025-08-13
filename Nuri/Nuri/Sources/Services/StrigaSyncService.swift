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
        print("[StrigaSyncService:syncUserData:17] Starting sync for user: \(userId)")
        
        // Clear any old cached data first to prevent conflicts
        clearCachedData()
        
        do {
            // Try to get user details, but don't fail if it doesn't work
            var userResponse: GetUserResponse? = nil
            do {
                let getUserInput = GetUser(userId: userId)
                userResponse = try await StrigaService.shared.getUser(getUserInput)
                print("[StrigaSyncService] User KYC Status: \(userResponse!.KYC.status)")
                
                // IMPORTANT: Do NOT overwrite names after KYC
                // In sandbox, KYC returns test names that would override the user's actual input
                // We only set names if they're not already in the session
                
                if StrigaSession.shared.firstName == nil || StrigaSession.shared.firstName?.isEmpty == true {
                    StrigaSession.shared.firstName = userResponse!.firstName
                    print("[StrigaSyncService] Set firstName from API: \(userResponse!.firstName)")
                } else {
                    print("[StrigaSyncService] Keeping existing firstName: \(StrigaSession.shared.firstName ?? "")")
                    if userResponse!.firstName != StrigaSession.shared.firstName {
                        print("[StrigaSyncService] WARNING: API returned different firstName: '\(userResponse!.firstName)' vs stored: '\(StrigaSession.shared.firstName ?? "")'")
                    }
                }
                
                if StrigaSession.shared.lastName == nil || StrigaSession.shared.lastName?.isEmpty == true {
                    StrigaSession.shared.lastName = userResponse!.lastName
                    print("[StrigaSyncService] Set lastName from API: \(userResponse!.lastName)")
                } else {
                    print("[StrigaSyncService] Keeping existing lastName: \(StrigaSession.shared.lastName ?? "")")
                    if userResponse!.lastName != StrigaSession.shared.lastName {
                        print("[StrigaSyncService] WARNING: API returned different lastName: '\(userResponse!.lastName)' vs stored: '\(StrigaSession.shared.lastName ?? "")'")
                    }
                }
                
                // Update combined name only if needed
                if StrigaSession.shared.name == nil || StrigaSession.shared.name?.isEmpty == true {
                    let firstName = StrigaSession.shared.firstName ?? userResponse!.firstName
                    let lastName = StrigaSession.shared.lastName ?? userResponse!.lastName
                    StrigaSession.shared.name = "\(firstName) \(lastName)"
                    print("[StrigaSyncService] Set combined name: \(StrigaSession.shared.name ?? "")")
                }
            } catch {
                print("[StrigaSyncService:syncUserData:31] Failed to get user details: \(error)")
                print("[StrigaSyncService:syncUserData:32] Continuing with sync anyway...")
            }
            // Store the user ID
            var settings = UserSettings()
            settings.strigaUserId = userId
            StrigaSession.shared.userId = userId
            
            // Fetch user's wallets
            let walletsResponse = try await StrigaService.shared.getWallets(userId: userId)
            print("[StrigaSyncService:syncUserData:42] Found \(walletsResponse.wallets.count) wallet(s) for user")
            
            guard let firstWallet = walletsResponse.wallets.first else {
                print("[StrigaSyncService:syncUserData:45] No wallets found for user")
                
                // If user has approved KYC but no wallets, this is an error state
                // The NuriApp should handle creating wallets/cards
                if userResponse?.KYC.status == "APPROVED" {
                    print("[StrigaSyncService] WARNING: KYC approved user has no wallets!")
                    print("[StrigaSyncService] This should be handled by automatic creation flow")
                } else if userResponse == nil {
                    print("[StrigaSyncService] Could not verify KYC status, but user has no wallets")
                }
                
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
            print("[StrigaSyncService:syncUserData:124] ❌ Sync failed: \(error)")
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