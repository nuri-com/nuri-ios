import Foundation
import StrigaAPI

/// Debug service to try different EUR enrichment approaches
class EUREnrichmentDebugger {
    static let shared = EUREnrichmentDebugger()
    private let striga = StrigaService.shared
    
    private init() {
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
        }
    }
    
    /// Try multiple approaches to enrich EUR account
    func tryAllEnrichmentApproaches(userId: String, walletId: String) async -> [String] {
        var logs: [String] = []
        
        logs.append("🔬 EUR ENRICHMENT DEBUGGER STARTED")
        logs.append("User ID: \(userId)")
        logs.append("Wallet ID: \(walletId)")
        
        // First, get wallet details
        do {
            let wallet = try await striga.getWallet(walletId, userId: userId)
            
            guard let eurAccount = wallet.accounts.eur else {
                logs.append("❌ No EUR account in wallet!")
                return logs
            }
            
            logs.append("\n📊 EUR Account Status:")
            logs.append("  Account ID: \(eurAccount.accountId)")
            logs.append("  Status: \(eurAccount.status)")
            logs.append("  Enriched: \(eurAccount.enriched)")
            logs.append("  Linked Card: \(eurAccount.linkedCardId ?? "NONE")")
            logs.append("  Has Banking Details: \(eurAccount.bankingDetails != nil)")
            
            if eurAccount.enriched {
                logs.append("✅ Already enriched!")
                if let iban = eurAccount.bankingDetails?.iban {
                    logs.append("  IBAN: \(iban)")
                }
                return logs
            }
            
            // Approach 1: Direct enrichment
            logs.append("\n🔄 Approach 1: Direct Enrichment")
            do {
                let result1 = try await striga.enrichAccount(.init(
                    accountId: eurAccount.accountId,
                    userId: userId
                ))
                logs.append("✅ Success! IBAN: \(result1.iban ?? "none")")
                return logs
            } catch {
                logs.append("❌ Failed: \(error)")
            }
            
            // Approach 2: With delay
            logs.append("\n🔄 Approach 2: With 3-second delay")
            try await Task.sleep(nanoseconds: 3_000_000_000)
            do {
                let result2 = try await striga.enrichAccount(.init(
                    accountId: eurAccount.accountId,
                    userId: userId
                ))
                logs.append("✅ Success! IBAN: \(result2.iban ?? "none")")
                return logs
            } catch {
                logs.append("❌ Failed: \(error)")
            }
            
            // Approach 3: Get fresh wallet data first
            logs.append("\n🔄 Approach 3: Fresh wallet data + enrichment")
            do {
                let freshWallet = try await striga.getWallet(walletId, userId: userId)
                if let freshEur = freshWallet.accounts.eur {
                    let result3 = try await striga.enrichAccount(.init(
                        accountId: freshEur.accountId,
                        userId: userId
                    ))
                    logs.append("✅ Success! IBAN: \(result3.iban ?? "none")")
                    return logs
                }
            } catch {
                logs.append("❌ Failed: \(error)")
            }
            
            // Approach 4: Try with the card's linked EUR account
            logs.append("\n🔄 Approach 4: Via card's linked account")
            if let cardId = eurAccount.linkedCardId, cardId != "UNLINKED" {
                do {
                    let card = try await striga.getCard(.init(
                        userId: userId,
                        cardId: cardId,
                        authToken: nil
                    ))
                    logs.append("  Card found: \(card.id)")
                    logs.append("  Card status: \(card.status)")
                    logs.append("  Linked account: \(card.linkedAccountId)")
                    
                    // Try enriching via card's linked account
                    let result4 = try await striga.enrichAccount(.init(
                        accountId: card.linkedAccountId,
                        userId: userId
                    ))
                    logs.append("✅ Success! IBAN: \(result4.iban ?? "none")")
                    return logs
                } catch {
                    logs.append("❌ Failed: \(error)")
                }
            }
            
            logs.append("\n❌ ALL APPROACHES FAILED")
            
        } catch {
            logs.append("❌ Fatal error: \(error)")
        }
        
        return logs
    }
    
    /// Check if crypto accounts can be enriched (to verify API works)
    func testCryptoEnrichment(userId: String, walletId: String) async -> [String] {
        var logs: [String] = []
        
        logs.append("🔬 CRYPTO ENRICHMENT TEST")
        
        do {
            let wallet = try await striga.getWallet(walletId, userId: userId)
            
            // Try BTC
            if let btc = wallet.accounts.btc, !btc.enriched {
                logs.append("\n🔄 Enriching BTC...")
                do {
                    let result = try await striga.enrichAccount(.init(
                        accountId: btc.accountId,
                        userId: userId
                    ))
                    logs.append("✅ BTC Success! Address: \(result.blockchainDepositAddress ?? "none")")
                } catch {
                    logs.append("❌ BTC Failed: \(error)")
                }
            }
            
            // Try SOL
            if let sol = wallet.accounts.sol, !sol.enriched {
                logs.append("\n🔄 Enriching SOL...")
                do {
                    let result = try await striga.enrichAccount(.init(
                        accountId: sol.accountId,
                        userId: userId
                    ))
                    logs.append("✅ SOL Success! Address: \(result.blockchainDepositAddress ?? "none")")
                } catch {
                    logs.append("❌ SOL Failed: \(error)")
                }
            }
            
        } catch {
            logs.append("❌ Error: \(error)")
        }
        
        return logs
    }
}