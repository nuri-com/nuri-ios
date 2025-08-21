import Foundation
import StrigaAPI

/// DEBUG SERVICE - FOR TESTING ONLY
/// Production enrichment is handled automatically by AutoConversionService
/// This service is used for manual testing and debugging enrichment issues
/// 
/// IMPORTANT: The app's normal flow uses AutoConversionService which:
/// - Runs every 60 seconds automatically
/// - Enriches accounts as needed before conversions
/// - Handles BTC to EUR conversion automatically
///
/// Use this service only from the Security screen for debugging
class WalletEnrichmentService {
    static let shared = WalletEnrichmentService()
    private let striga = StrigaService.shared
    
    private init() {
        // Ensure Striga is configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
        }
    }
    
    struct EnrichmentResult {
        let timestamp: String
        let userId: String
        let cardId: String?
        let walletId: String?
        let logs: [String]
        let success: Bool
        let eurAccountEnriched: Bool
        let cryptoAccountsEnriched: [String: Bool]
        let cardLinked: Bool
    }
    
    func performFullEnrichmentAndLinking() async -> EnrichmentResult {
        var logs: [String] = []
        var success = false
        var eurAccountEnriched = false
        var cryptoAccountsEnriched: [String: Bool] = [:]
        var cardLinked = false
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logs.append("\n════════════════════════════════════════")
        logs.append("🔬 WALLET ENRICHMENT & CARD LINKING TEST")
        logs.append("📅 \(timestamp)")
        logs.append("════════════════════════════════════════\n")
        
        // Step 1: Get User ID
        let userId = UserSettings().strigaUserId ?? StrigaSession.shared.userId ?? ""
        if userId.isEmpty {
            logs.append("❌ FATAL: No User ID found!")
            logs.append("   - UserSettings: \(UserSettings().strigaUserId ?? "nil")")
            logs.append("   - Session: \(StrigaSession.shared.userId ?? "nil")")
            return EnrichmentResult(
                timestamp: timestamp,
                userId: "",
                cardId: nil,
                walletId: nil,
                logs: logs,
                success: false,
                eurAccountEnriched: false,
                cryptoAccountsEnriched: [:],
                cardLinked: false
            )
        }
        
        logs.append("✅ Step 1: User ID Found")
        logs.append("   👤 User ID: \(userId)")
        
        // Step 2: Get Card ID
        let cardId = UserSettings().strigaCardId ?? StrigaSession.shared.cardId
        logs.append("\n📍 Step 2: Card Information")
        if let cardId = cardId, !cardId.isEmpty, cardId != "UNLINKED" {
            logs.append("   ✅ Card ID: \(cardId)")
        } else {
            logs.append("   ⚠️ No valid card found")
            logs.append("   - UserSettings: \(UserSettings().strigaCardId ?? "nil")")
            logs.append("   - Session: \(StrigaSession.shared.cardId ?? "nil")")
        }
        
        // Step 3: Get Wallets
        logs.append("\n📍 Step 3: Fetching Wallets...")
        do {
            let walletsResponse = try await striga.getWallets(userId: userId)
            logs.append("   ✅ Found \(walletsResponse.wallets.count) wallet(s)")
            
            guard let wallet = walletsResponse.wallets.first else {
                logs.append("   ❌ No wallets found for user!")
                return EnrichmentResult(
                    timestamp: timestamp,
                    userId: userId,
                    cardId: cardId,
                    walletId: nil,
                    logs: logs,
                    success: false,
                    eurAccountEnriched: false,
                    cryptoAccountsEnriched: [:],
                    cardLinked: false
                )
            }
            
            let walletId = wallet.walletId
            logs.append("   📂 Using wallet: \(walletId)")
            logs.append("   💰 Balance: \(wallet.walletBalance)")
            
            // Step 4: Check and Link Card to EUR Account
            logs.append("\n📍 Step 4: Card Linking Check")
            if let eurAccount = wallet.accounts.eur {
                logs.append("   💶 EUR Account ID: \(eurAccount.accountId)")
                logs.append("   - Status: \(eurAccount.status)")
                logs.append("   - Enriched: \(eurAccount.enriched)")
                logs.append("   - Current Card ID: \(eurAccount.linkedCardId ?? "NONE")")
                
                // Check if card needs linking
                if let cardId = cardId, 
                   !cardId.isEmpty, 
                   cardId != "UNLINKED",
                   (eurAccount.linkedCardId == nil || eurAccount.linkedCardId == "UNLINKED" || eurAccount.linkedCardId != cardId) {
                    
                    logs.append("\n   🔗 Attempting to link card to EUR account...")
                    do {
                        // Note: There's no direct API to link card to account after creation
                        // Cards are linked during creation. If unlinked, may need to recreate
                        logs.append("   ⚠️ Card linking after creation requires card recreation")
                        logs.append("   ℹ️ Cards must be linked during creation via linkedAccountId")
                        
                        // Check if the card is already linked to a different account
                        let cardDetails = try await striga.getCard(.init(
                            userId: userId,
                            cardId: cardId,
                            authToken: nil
                        ))
                        
                        logs.append("   📊 Card Details:")
                        logs.append("     - Parent Wallet: \(cardDetails.parentWalletId)")
                        logs.append("     - Status: \(cardDetails.status)")
                        logs.append("     - Type: \(cardDetails.type)")
                        
                        if cardDetails.parentWalletId == walletId {
                            logs.append("   ✅ Card is correctly associated with this wallet")
                            cardLinked = true
                        } else {
                            logs.append("   ❌ Card belongs to different wallet: \(cardDetails.parentWalletId)")
                        }
                        
                    } catch {
                        logs.append("   ❌ Error checking card: \(error)")
                    }
                } else if let linkedCard = eurAccount.linkedCardId, linkedCard != "UNLINKED" {
                    logs.append("   ✅ Card already linked: \(linkedCard)")
                    cardLinked = true
                } else {
                    logs.append("   ⚠️ No card to link")
                }
            } else {
                logs.append("   ❌ No EUR account found!")
            }
            
            // Step 5: Enrich EUR Account
            logs.append("\n📍 Step 5: EUR Account Enrichment")
            if let eurAccount = wallet.accounts.eur {
                if eurAccount.enriched {
                    logs.append("   ✅ EUR account already enriched")
                    if let iban = eurAccount.bankingDetails?.iban {
                        logs.append("   🏦 IBAN: \(iban)")
                        logs.append("   🏦 BIC: \(eurAccount.bankingDetails?.bic ?? "N/A")")
                        logs.append("   🏦 Name: \(eurAccount.bankingDetails?.accountHolderName ?? "N/A")")
                    }
                    eurAccountEnriched = true
                } else {
                    logs.append("   🔄 Enriching EUR account...")
                    do {
                        let enrichResult = try await striga.enrichAccount(.init(
                            accountId: eurAccount.accountId,
                            userId: userId
                        ))
                        
                        logs.append("   ✅ EUR account enriched successfully!")
                        if let iban = enrichResult.iban {
                            logs.append("   🏦 IBAN: \(iban)")
                            logs.append("   🏦 BIC: \(enrichResult.bic ?? "N/A")")
                        }
                        eurAccountEnriched = true
                        
                    } catch {
                        logs.append("   ❌ EUR enrichment failed: \(error)")
                        if let errorResponse = error as? ErrorResponse {
                            logs.append("     Error Code: \(errorResponse.errorCode)")
                            logs.append("     Message: \(errorResponse.message)")
                            logs.append("     Details: \(errorResponse.errorDetails ?? "none")")
                        }
                    }
                }
            }
            
            // Step 6: Enrich Crypto Accounts
            logs.append("\n📍 Step 6: Crypto Accounts Enrichment")
            
            // BTC Account
            if let btcAccount = wallet.accounts.btc {
                logs.append("\n   ₿ Bitcoin Account:")
                logs.append("     - Account ID: \(btcAccount.accountId)")
                logs.append("     - Enriched: \(btcAccount.enriched)")
                
                if btcAccount.enriched {
                    if let address = btcAccount.blockchainDepositAddress {
                        logs.append("     ✅ Already enriched")
                        logs.append("     📍 Address: \(address)")
                        cryptoAccountsEnriched["BTC"] = true
                    } else {
                        logs.append("     ⚠️ Marked as enriched but no address, re-enriching...")
                        do {
                            let enrichResult = try await striga.enrichAccount(.init(
                                accountId: btcAccount.accountId,
                                userId: userId
                            ))
                            
                            if let address = enrichResult.blockchainDepositAddress {
                                logs.append("     ✅ Re-enriched successfully!")
                                logs.append("     📍 Address: \(address)")
                                cryptoAccountsEnriched["BTC"] = true
                            } else if let networks = enrichResult.blockchainNetworks, !networks.isEmpty {
                                logs.append("     ✅ Re-enriched with networks!")
                                logs.append("     📍 Address: \(networks[0].blockchainDepositAddress ?? "none")")
                                cryptoAccountsEnriched["BTC"] = true
                            }
                        } catch {
                            logs.append("     ❌ Re-enrichment failed: \(error)")
                            cryptoAccountsEnriched["BTC"] = false
                        }
                    }
                } else {
                    logs.append("     🔄 Enriching BTC account...")
                    do {
                        let enrichResult = try await striga.enrichAccount(.init(
                            accountId: btcAccount.accountId,
                            userId: userId
                        ))
                        
                        if let address = enrichResult.blockchainDepositAddress {
                            logs.append("     ✅ BTC enriched successfully!")
                            logs.append("     📍 Address: \(address)")
                            cryptoAccountsEnriched["BTC"] = true
                        } else if let networks = enrichResult.blockchainNetworks, !networks.isEmpty {
                            logs.append("     ✅ BTC enriched with networks!")
                            logs.append("     📍 Address: \(networks[0].blockchainDepositAddress ?? "none")")
                            cryptoAccountsEnriched["BTC"] = true
                        } else {
                            logs.append("     ⚠️ Enriched but no address returned")
                            cryptoAccountsEnriched["BTC"] = false
                        }
                        
                    } catch {
                        logs.append("     ❌ BTC enrichment failed: \(error)")
                        cryptoAccountsEnriched["BTC"] = false
                    }
                }
            }
            
            // ETH Account
            if let ethAccount = wallet.accounts.eth {
                logs.append("\n   Ξ Ethereum Account:")
                logs.append("     - Account ID: \(ethAccount.accountId)")
                logs.append("     - Enriched: \(ethAccount.enriched)")
                
                if !ethAccount.enriched {
                    logs.append("     🔄 Enriching ETH account...")
                    do {
                        let enrichResult = try await striga.enrichAccount(.init(
                            accountId: ethAccount.accountId,
                            userId: userId
                        ))
                        
                        if let address = enrichResult.blockchainDepositAddress {
                            logs.append("     ✅ ETH enriched successfully!")
                            logs.append("     📍 Address: \(address)")
                            cryptoAccountsEnriched["ETH"] = true
                        }
                    } catch {
                        logs.append("     ❌ ETH enrichment failed: \(error)")
                        cryptoAccountsEnriched["ETH"] = false
                    }
                } else {
                    logs.append("     ✅ Already enriched")
                    if let address = ethAccount.blockchainDepositAddress {
                        logs.append("     📍 Address: \(address)")
                    }
                    cryptoAccountsEnriched["ETH"] = true
                }
            }
            
            // SOL Account
            if let solAccount = wallet.accounts.sol {
                logs.append("\n   ◎ Solana Account:")
                logs.append("     - Account ID: \(solAccount.accountId)")
                logs.append("     - Enriched: \(solAccount.enriched)")
                
                if !solAccount.enriched {
                    logs.append("     🔄 Enriching SOL account...")
                    do {
                        let enrichResult = try await striga.enrichAccount(.init(
                            accountId: solAccount.accountId,
                            userId: userId
                        ))
                        
                        if let address = enrichResult.blockchainDepositAddress {
                            logs.append("     ✅ SOL enriched successfully!")
                            logs.append("     📍 Address: \(address)")
                            cryptoAccountsEnriched["SOL"] = true
                        }
                    } catch {
                        logs.append("     ❌ SOL enrichment failed: \(error)")
                        cryptoAccountsEnriched["SOL"] = false
                    }
                } else {
                    logs.append("     ✅ Already enriched")
                    if let address = solAccount.blockchainDepositAddress {
                        logs.append("     📍 Address: \(address)")
                    }
                    cryptoAccountsEnriched["SOL"] = true
                }
            }
            
            // Final Summary
            logs.append("\n════════════════════════════════════════")
            logs.append("📊 ENRICHMENT SUMMARY")
            logs.append("════════════════════════════════════════")
            logs.append("✅ User ID: \(userId)")
            logs.append("💳 Card ID: \(cardId ?? "NONE")")
            logs.append("📂 Wallet ID: \(walletId)")
            logs.append("💶 EUR Enriched: \(eurAccountEnriched ? "✅" : "❌")")
            logs.append("🔗 Card Linked: \(cardLinked ? "✅" : "❌")")
            
            for (crypto, enriched) in cryptoAccountsEnriched {
                logs.append("\(crypto) Enriched: \(enriched ? "✅" : "❌")")
            }
            
            success = eurAccountEnriched || !cryptoAccountsEnriched.isEmpty
            logs.append("\n🎯 Overall Status: \(success ? "SUCCESS ✅" : "FAILED ❌")")
            logs.append("════════════════════════════════════════\n")
            
            return EnrichmentResult(
                timestamp: timestamp,
                userId: userId,
                cardId: cardId,
                walletId: walletId,
                logs: logs,
                success: success,
                eurAccountEnriched: eurAccountEnriched,
                cryptoAccountsEnriched: cryptoAccountsEnriched,
                cardLinked: cardLinked
            )
            
        } catch {
            logs.append("❌ Fatal error fetching wallets: \(error)")
            if let errorResponse = error as? ErrorResponse {
                logs.append("   Error Code: \(errorResponse.errorCode)")
                logs.append("   Message: \(errorResponse.message)")
                logs.append("   Details: \(errorResponse.errorDetails ?? "none")")
            }
            
            return EnrichmentResult(
                timestamp: timestamp,
                userId: userId,
                cardId: cardId,
                walletId: nil,
                logs: logs,
                success: false,
                eurAccountEnriched: false,
                cryptoAccountsEnriched: [:],
                cardLinked: false
            )
        }
    }
}