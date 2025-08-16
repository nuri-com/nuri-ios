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
        print("\n" + String(repeating: "=", count: 80))
        print("🔄 [StrigaSyncService] STARTING FULL SYNC")
        print("📱 Sync Type: \(UserSettings().strigaCardId == nil ? "FRESH INSTALL/RECOVERY" : "EXISTING USER")")
        print("👤 User ID: \(userId)")
        print("💳 Current Card ID: \(UserSettings().strigaCardId ?? "NONE")")
        print("👛 Current Wallet ID: \(UserSettings().strigaWalletId ?? "NONE")")
        print(String(repeating: "=", count: 80))
        
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
                print("[StrigaSyncService:syncUserData:32] This is expected - /users/get endpoint doesn't exist")
                print("[StrigaSyncService] Continuing with wallet check...")
            }
            // Store the user ID
            UserSettings().strigaUserId = userId
            StrigaSession.shared.userId = userId
            
            // Fetch user's wallets
            print("\n📊 [StrigaSyncService] STEP 1: Fetching wallets...")
            let walletsResponse = try await StrigaService.shared.getWallets(userId: userId)
            print("✅ [StrigaSyncService] Found \(walletsResponse.wallets.count) wallet(s)")
            
            // Log wallet details
            for (index, wallet) in walletsResponse.wallets.enumerated() {
                print("\n👛 Wallet #\(index + 1):")
                print("   ID: \(wallet.walletId)")
                print("   Created: \(wallet.createdAt)")
                print("   Comment: \(wallet.comment as String? ?? "none")")
            }
            
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
            UserSettings().strigaWalletId = firstWallet.walletId
            print("[StrigaSyncService] Stored wallet ID: \(firstWallet.walletId)")
            
            // Find linked card from wallet accounts
            print("\n🔍 [StrigaSyncService] STEP 2: Searching for existing cards...")
            var foundCardId: String?
            
            print("📝 Checking first wallet (\(firstWallet.walletId)):")
            
            // Check EUR account for linked card (most common)
            if let eurAccount = firstWallet.accounts.eur {
                print("   EUR Account ID: \(eurAccount.accountId)")
                print("   EUR linkedCardId: \(eurAccount.linkedCardId as String? ?? "nil")")
                
                if let linkedCardId = eurAccount.linkedCardId,
                   linkedCardId != "UNLINKED" && !linkedCardId.isEmpty {
                    foundCardId = linkedCardId
                    print("   ✅ Found valid card: \(linkedCardId)")
                } else {
                    print("   ❌ No valid card (UNLINKED or empty)")
                }
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
                    if let linkedCardId = account.linkedCardId,
                       linkedCardId != "UNLINKED" && !linkedCardId.isEmpty {
                        foundCardId = linkedCardId
                        print("[StrigaSyncService] Found card linked to \(account.currency) account: \(linkedCardId)")
                        break
                    }
                }
            }
            
            // If still no card found, check ALL wallet accounts (not just the first wallet)
            if foundCardId == nil && walletsResponse.wallets.count > 1 {
                print("\n🔍 No card in first wallet, checking remaining \(walletsResponse.wallets.count - 1) wallet(s)...")
                
                for (index, wallet) in walletsResponse.wallets.dropFirst().enumerated() {
                    print("\n📝 Checking wallet #\(index + 2) (\(wallet.walletId)):")
                    
                    // Check all accounts in this wallet
                    let allAccounts = [
                        wallet.accounts.eur,
                        wallet.accounts.btc,
                        wallet.accounts.eth,
                        wallet.accounts.usdc,
                        wallet.accounts.usdt,
                        wallet.accounts.sol,
                        wallet.accounts.bnb,
                        wallet.accounts.pol
                    ].compactMap { $0 }
                    
                    for account in allAccounts {
                        print("   \(account.currency) Account: \(account.accountId)")
                        print("   \(account.currency) linkedCardId: \(account.linkedCardId as String? ?? "nil")")
                        
                        if let linkedCardId = account.linkedCardId,
                           linkedCardId != "UNLINKED" && !linkedCardId.isEmpty {
                            foundCardId = linkedCardId
                            print("   ✅ FOUND VALID CARD: \(linkedCardId)")
                            print("   📍 Card is in wallet: \(wallet.walletId)")
                            print("   💱 Card is linked to: \(account.currency) account")
                            
                            // Also update the wallet ID to the one with the card
                            UserSettings().strigaWalletId = wallet.walletId
                            print("   ✅ Updated stored wallet ID to: \(wallet.walletId)")
                            break
                        }
                    }
                    if foundCardId != nil { break }
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
                    UserSettings().strigaCardId = cardId
                    StrigaSession.shared.cardId = cardId
                    print("[StrigaSyncService] Successfully verified and stored card: \(cardId)")
                    print("[StrigaSyncService] Card status: \(cardResponse.status)")
                    
                } catch {
                    print("[StrigaSyncService] Failed to verify card \(cardId): \(error)")
                    // Don't store invalid card ID
                }
            } else {
                print("\n⚠️ [StrigaSyncService] No card found in any wallet")
                print("📝 This user needs to create a card")
            }
            
            // Final sync summary
            print("\n" + String(repeating: "=", count: 80))
            print("✅ [StrigaSyncService] SYNC COMPLETED SUCCESSFULLY")
            print("📊 Final State:")
            print("   👤 User ID: \(userId)")
            print("   👛 Wallet ID: \(UserSettings().strigaWalletId as String? ?? "none")")
            print("   💳 Card ID: \(UserSettings().strigaCardId as String? ?? "none")")
            print("   🏦 Total Wallets: \(walletsResponse.wallets.count)")
            
            if UserSettings().strigaCardId == nil {
                print("\n⚠️ ACTION REQUIRED: User needs to create a card")
            } else {
                print("\n✅ User is fully set up with card and wallet")
            }
            print(String(repeating: "=", count: 80) + "\n")
            
            return true
            
        } catch {
            print("\n" + String(repeating: "=", count: 80))
            print("❌ [StrigaSyncService] SYNC FAILED")
            print("Error: \(error)")
            print(String(repeating: "=", count: 80) + "\n")
            return false
        }
    }
    
    /// Clears all cached Striga IDs to prevent conflicts
    private func clearCachedData() {
        print("[StrigaSyncService] Clearing cached Striga data")
        
        let settings = UserSettings()
        
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