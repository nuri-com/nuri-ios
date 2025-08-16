import Foundation
import StrigaAPI

// Protocol to abstract Striga card creation
protocol CardCreationServiceProtocol {
    func createCard(name: String, userId: String) async throws -> CardCreationResult
    func createUser(firstName: String, lastName: String, email: String, mobile: MobileInfo, address: AddressInfo, dateOfBirth: DateInfo) async throws -> String
    func verifyMobile(userId: String, verificationCode: String) async throws
    func startKYC(userId: String) async throws -> String
}

struct CardCreationResult {
    let id: String
    let parentWalletId: String
}

struct MobileInfo {
    let countryCode: String
    let number: String
}

struct AddressInfo {
    let addressLine1: String
    let city: String
    let country: String
    let postalCode: String
}

struct DateInfo {
    let year: Int32
    let month: Int32
    let day: Int32
}

// Mock implementation for the main target
class MockCardCreationService: CardCreationServiceProtocol {
    func createCard(name: String, userId: String) async throws -> CardCreationResult {
        // This would be replaced with actual Striga API call in a real implementation
        return CardCreationResult(id: "mock-card-id", parentWalletId: "mock-wallet-id")
    }
    
    func createUser(firstName: String, lastName: String, email: String, mobile: MobileInfo, address: AddressInfo, dateOfBirth: DateInfo) async throws -> String {
        // AGGRESSIVE LOGGING
        print("[GEMINI] CardCreationService.swift: MockCardCreationService.createUser called with firstName: \(firstName), lastName: \(lastName)")
        // Mock implementation
        return "mock-user-id"
    }
    
    func verifyMobile(userId: String, verificationCode: String) async throws {
        // Mock implementation
    }
    
    func startKYC(userId: String) async throws -> String {
        // Mock implementation
        return "mock-kyc-token"
    }
}

// Real Striga implementation
class StrigaCardCreationService: CardCreationServiceProtocol {
    private let striga = StrigaService.shared
    
    init() {
        // Configure Striga if not already configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
            print("[StrigaCardCreation] Configured with Striga credentials")
        }
    }
    
    func createCard(name: String, userId: String) async throws -> CardCreationResult {
        print("\n" + String(repeating: "=", count: 80))
        print("🎯 [StrigaCardCreation] STARTING CARD CREATION PROCESS")
        print("   👤 User ID: \(userId)")
        print("   📝 Card Name: \(name)")
        print("   🔄 Process: Check wallets → Create if needed → Enrich → Create card")
        print(String(repeating: "=", count: 80))
        
        var walletId: String = ""
        var linkedAccountId: String = ""
        
        // Try to get existing wallets first
        do {
            print("\n📊 [StrigaCardCreation] STEP 1: Checking for existing wallets...")
            let walletsResponse = try await striga.getWallets(userId: userId)
            print("[StrigaCardCreation] Found \(walletsResponse.wallets.count) wallet(s)")
            
            // Check if any wallet already has a valid card
            for wallet in walletsResponse.wallets {
                let hasValidCard = [
                    wallet.accounts.eur?.linkedCardId,
                    wallet.accounts.btc?.linkedCardId,
                    wallet.accounts.eth?.linkedCardId,
                    wallet.accounts.usdc?.linkedCardId,
                    wallet.accounts.usdt?.linkedCardId
                ].contains { cardId in
                    cardId != nil && cardId != "UNLINKED" && !cardId!.isEmpty
                }
                
                if hasValidCard {
                    print("[StrigaCardCreation] ⚠️ Wallet \(wallet.walletId) already has a card - skipping card creation")
                    // Don't create another card - just return the existing one
                    if let eurCardId = wallet.accounts.eur?.linkedCardId,
                       eurCardId != "UNLINKED" && !eurCardId.isEmpty {
                        return CardCreationResult(id: eurCardId, parentWalletId: wallet.walletId)
                    }
                }
            }
            
            // Find a wallet without a card, or use the first wallet
            let walletWithoutCard = walletsResponse.wallets.first { wallet in
                let cardIds = [
                    wallet.accounts.eur?.linkedCardId,
                    wallet.accounts.btc?.linkedCardId,
                    wallet.accounts.eth?.linkedCardId,
                    wallet.accounts.usdc?.linkedCardId,
                    wallet.accounts.usdt?.linkedCardId
                ].compactMap { $0 }
                
                // Check if all card IDs are either empty or "UNLINKED"
                return cardIds.allSatisfy { $0 == "UNLINKED" || $0.isEmpty }
            }
            
            if let existingWallet = walletWithoutCard ?? walletsResponse.wallets.first {
                // Use existing wallet (preferring one without a card)
                print("[StrigaCardCreation] Using wallet: \(existingWallet.walletId)")
                walletId = existingWallet.walletId
                
                // Get full wallet details to access accounts
                let walletDetails = try await striga.getWallet(
                    walletId,
                    userId: userId
                )
                
                // Enrich BTC account if not already enriched
                if let btcAccount = walletDetails.accounts.btc {
                    if !btcAccount.enriched {
                        print("[StrigaCardCreation] BTC account needs enrichment for blockchain address")
                        do {
                            let btcEnrichResult = try await striga.enrichAccount(.init(
                                accountId: btcAccount.accountId,
                                userId: userId
                            ))
                            if let btcAddress = btcEnrichResult.blockchainDepositAddress {
                                print("[StrigaCardCreation] ✅ BTC address generated: \(btcAddress.prefix(10))...")
                            }
                        } catch {
                            print("[StrigaCardCreation] ⚠️ Failed to enrich BTC account: \(error)")
                            // Not critical for card creation, but important for receiving BTC
                        }
                    } else {
                        print("[StrigaCardCreation] BTC account already enriched")
                    }
                }
                
                // Check if EUR account needs enrichment
                if let eurAccount = walletDetails.accounts.eur {
                    if !eurAccount.enriched {
                        print("[StrigaCardCreation] EUR account needs enrichment (no IBAN yet)")
                        print("[StrigaCardCreation] Enriching EUR account: \(eurAccount.accountId)")
                        do {
                            let enrichResult = try await striga.enrichAccount(.init(
                                accountId: eurAccount.accountId,
                                userId: userId
                            ))
                            print("[StrigaCardCreation] ✅ EUR account enriched successfully")
                            if let iban = enrichResult.iban {
                                print("[StrigaCardCreation] IBAN: \(iban)")
                            }
                        } catch {
                            print("[StrigaCardCreation] ❌ Failed to enrich EUR account: \(error)")
                            // This is critical - without IBAN, user can't receive EUR
                            throw NSError(domain: "StrigaCardCreation", code: 3,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to enrich EUR account with IBAN: \(error)"])
                        }
                    } else {
                        print("[StrigaCardCreation] EUR account already enriched")
                    }
                    linkedAccountId = eurAccount.accountId
                } else {
                    throw NSError(domain: "StrigaCardCreation", code: 1, 
                                userInfo: [NSLocalizedDescriptionKey: "Existing wallet has no EUR account"])
                }
            } else {
                // No wallets found, create a new one
                print("[StrigaCardCreation] No wallets found, creating new wallet...")
                throw NSError(domain: "StrigaCardCreation", code: 2, 
                            userInfo: [NSLocalizedDescriptionKey: "No wallets - will create"])
            }
        } catch {
            // If getWallets fails or no wallets exist, create a new wallet
            print("[StrigaCardCreation] Error checking wallets: \(error)")
            
            // First, try to get wallets again to make sure we don't have any
            // This prevents duplicate wallet creation due to transient errors
            var shouldCreateWallet = true
            
            do {
                print("[StrigaCardCreation] Double-checking for existing wallets...")
                let doubleCheckResponse = try await striga.getWallets(userId: userId)
                if !doubleCheckResponse.wallets.isEmpty {
                    print("[StrigaCardCreation] ⚠️ Found \(doubleCheckResponse.wallets.count) wallet(s) on double-check!")
                    print("[StrigaCardCreation] Using first wallet instead of creating new one")
                    
                    let existingWallet = doubleCheckResponse.wallets[0]
                    walletId = existingWallet.walletId
                    
                    // Get wallet details
                    let walletDetails = try await striga.getWallet(walletId, userId: userId)
                    
                    // Use EUR account from existing wallet
                    if let eurAccount = walletDetails.accounts.eur {
                        linkedAccountId = eurAccount.accountId
                        print("[StrigaCardCreation] Using existing EUR account: \(linkedAccountId)")
                        shouldCreateWallet = false
                    } else {
                        throw NSError(domain: "StrigaCardCreation", code: 6,
                                    userInfo: [NSLocalizedDescriptionKey: "Existing wallet has no EUR account"])
                    }
                }
            } catch let doubleCheckError {
                print("[StrigaCardCreation] Double-check also failed: \(doubleCheckError)")
            }
            
            if shouldCreateWallet {
                print("[StrigaCardCreation] Confirmed: No wallets exist. Creating new wallet...")
            
            let walletResponse = try await striga.createWallet(.init(
                userId: userId,
                accountCurrency: ["EUR", "BTC"]
            ))
            walletId = walletResponse.walletId
            print("[StrigaCardCreation] Wallet created: \(walletId)")
            
            // Enrich BTC account first to get blockchain address
            if let btcAccount = walletResponse.accounts.btc {
                print("[StrigaCardCreation] Enriching BTC account for blockchain address...")
                do {
                    let btcEnrichResult = try await striga.enrichAccount(.init(
                        accountId: btcAccount.accountId,
                        userId: userId
                    ))
                    if let btcAddress = btcEnrichResult.blockchainDepositAddress {
                        print("[StrigaCardCreation] ✅ BTC address generated: \(btcAddress.prefix(10))...")
                    }
                } catch {
                    print("[StrigaCardCreation] ⚠️ Failed to enrich BTC account: \(error)")
                    // Not critical - BTC enrichment can be retried later
                }
            }
            
            // Enrich EUR account for new wallet - CRITICAL for receiving EUR from swaps
            if let eurAccount = walletResponse.accounts.eur {
                print("[StrigaCardCreation] New wallet created - EUR account needs enrichment for IBAN")
                print("[StrigaCardCreation] Enriching EUR account: \(eurAccount.accountId)")
                
                // Add delay and retry for EUR enrichment to avoid OpenPaydAccountError
                var eurEnrichSuccess = false
                var eurEnrichRetries = 0
                let maxEurRetries = 3
                
                while eurEnrichRetries < maxEurRetries && !eurEnrichSuccess {
                    do {
                        // Add delay before enrichment to let account settle
                        if eurEnrichRetries > 0 {
                            print("[StrigaCardCreation] Retry \(eurEnrichRetries)/\(maxEurRetries) after delay...")
                            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 second delay
                        } else {
                            // Initial delay to let account creation settle
                            print("[StrigaCardCreation] Waiting 2 seconds for account to settle before enrichment...")
                            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second initial delay
                        }
                        
                        let enrichResult = try await striga.enrichAccount(.init(
                            accountId: eurAccount.accountId,
                            userId: userId
                        ))
                        print("[StrigaCardCreation] ✅ EUR account enriched successfully")
                        if let iban = enrichResult.iban {
                            print("[StrigaCardCreation] IBAN generated: \(iban)")
                            eurEnrichSuccess = true
                        } else {
                            print("[StrigaCardCreation] ⚠️ Enrichment succeeded but no IBAN returned")
                            eurEnrichSuccess = true // Still consider it success
                        }
                        linkedAccountId = eurAccount.accountId
                    } catch {
                        eurEnrichRetries += 1
                        print("[StrigaCardCreation] ⚠️ EUR enrichment attempt \(eurEnrichRetries) failed: \(error)")
                        
                        if eurEnrichRetries >= maxEurRetries {
                            print("[StrigaCardCreation] ❌ Failed to enrich EUR account after \(maxEurRetries) attempts")
                            // Don't throw - continue with card creation
                            // The account can be enriched later
                            print("[StrigaCardCreation] ⚠️ Continuing with card creation - EUR enrichment can be done later")
                            linkedAccountId = eurAccount.accountId
                            break
                        }
                    }
                }
            } else {
                throw NSError(domain: "StrigaCardCreation", code: 5,
                            userInfo: [NSLocalizedDescriptionKey: "New wallet has no EUR account - critical error"])
            }
            } // Close the shouldCreateWallet if statement
        }
        
        // Generate a secure password for 3D Secure
        let password = generateSecurePassword()
        
        // Then create the card
        print("[StrigaCardCreation] Creating card with:")
        print("[StrigaCardCreation] - Name: \(name)")
        print("[StrigaCardCreation] - User ID: \(userId)")
        print("[StrigaCardCreation] - Parent Wallet ID: \(walletId)")
        print("[StrigaCardCreation] - Linked Account ID: \(linkedAccountId)")
        print("[StrigaCardCreation] - Type: VIRTUAL")
        
        let cardResponse = try await striga.createCard(.init(
            userId: userId,
            linkedAccountId: linkedAccountId,
            name: name,
            nameOnCard: name,
            parentWalletId: walletId,
            type: "VIRTUAL",
            threeDSecurePassword: password
        ))
        
        print("\n" + String(repeating: "=", count: 80))
        print("✅ [StrigaCardCreation] CARD CREATION SUCCESSFUL!")
        print("   💳 Card ID: \(cardResponse.id)")
        print("   👛 Wallet ID: \(walletId)")
        print("   💱 Linked Account: \(linkedAccountId)")
        print("   📱 Card Type: VIRTUAL")
        print("   ✅ Ready for Apple Pay")
        print(String(repeating: "=", count: 80) + "\n")
        
        // IMPORTANT: Try to enrich EUR account after card is created and linked
        // This is needed for auto-swap functionality
        print("\n🔄 [StrigaCardCreation] POST-CARD EUR ENRICHMENT FOR AUTO-SWAP:")
        print("   Attempting to enrich EUR account for auto-swap functionality...")
        print("   Account ID: \(linkedAccountId)")
        
        do {
            // Add a small delay to let the card linking settle
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            let enrichResult = try await striga.enrichAccount(.init(
                accountId: linkedAccountId,
                userId: userId
            ))
            
            print("✅ [StrigaCardCreation] EUR account enriched successfully!")
            if let iban = enrichResult.iban {
                print("   IBAN: \(iban)")
                if let bic = enrichResult.bic {
                    print("   BIC: \(bic)")
                }
            }
            print("   Auto-swap from crypto to EUR is now enabled!")
            
        } catch {
            print("⚠️ [StrigaCardCreation] EUR enrichment failed: \(error)")
            print("   This means auto-swap won't work until EUR is enriched")
            print("   User can manually enrich from Security > Striga Debug")
            
            // Log detailed error for debugging
            if let nsError = error as? NSError {
                print("   Error code: \(nsError.code)")
                print("   Error domain: \(nsError.domain)")
            }
            // Don't fail card creation - enrichment can be done later
        }
        
        return CardCreationResult(
            id: cardResponse.id,
            parentWalletId: walletId
        )
    }
    
    private func generateSecurePassword() -> String {
        // Use safer subset of allowed characters to avoid HMAC encoding issues
        // Avoiding: " \ / which can cause JSON/HMAC encoding problems
        let uppercase = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
        let numbers = Array("0123456789")
        let special = Array("!#;:?&*()+=,.[]{}")
        
        // Use 16 characters for a strong password
        var password = ""
        
        // Ensure at least 2 of each type for strength
        password.append(contentsOf: [uppercase.randomElement()!, uppercase.randomElement()!])
        password.append(contentsOf: [lowercase.randomElement()!, lowercase.randomElement()!])
        password.append(contentsOf: [numbers.randomElement()!, numbers.randomElement()!])
        password.append(contentsOf: [special.randomElement()!, special.randomElement()!])
        
        // Fill remaining 8 characters
        let allCharacters = uppercase + lowercase + numbers + special
        for _ in 0..<8 {
            password.append(allCharacters.randomElement()!)
        }
        
        // Shuffle the password
        return String(password.shuffled())
    }
    
    func createUser(firstName: String, lastName: String, email: String, mobile: MobileInfo, address: AddressInfo, dateOfBirth: DateInfo) async throws -> String {
        // This is implemented in EnterSMSCodeViewModel
        throw NSError(domain: "StrigaCardCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use EnterSMSCodeViewModel for user creation"])
    }
    
    func verifyMobile(userId: String, verificationCode: String) async throws {
        // This is implemented in EnterSMSCodeViewModel
        throw NSError(domain: "StrigaCardCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use EnterSMSCodeViewModel for mobile verification"])
    }
    
    func startKYC(userId: String) async throws -> String {
        // This is implemented in EnterSMSCodeViewModel
        throw NSError(domain: "StrigaCardCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use EnterSMSCodeViewModel for KYC"])
    }
}

// Singleton to provide the service
class CardCreationServiceProvider {
    static let shared = CardCreationServiceProvider()
    var service: CardCreationServiceProtocol = StrigaCardCreationService()
    
    private init() {}
}