import SwiftUI

struct SetAmountView: View {
    let recipientAddress: String
    
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletState = WalletStateManager.shared

    @State private var navigateToConfirm = false
    @State private var satsToEurRate: Double = 0.0005 // Default fallback rate
    @State private var btcToEurRate: Double = 50000.0 // Default fallback rate

    // Amounts to forward to confirmation screen  
    @State private var btcAmount: Double = 0 // Still in BTC for compatibility with ConfirmTransactionView
    @State private var eurAmount: Double = 0

    var body: some View {
        ZStack {
            AmountEntryScreen(
                title: "₿ \(formatSats(walletState.availableBalance)) Balance",
                primarySymbol: "€",
                secondarySymbol: "₿",
                initialPrimaryIsCrypto: false,
                exchangeRate: $btcToEurRate,
                availableBalance: walletState.availableBalance,
                walletState: walletState,
                actionIcon: "money_topup",
                actionTitle: "Confirm Amount",
                onSubmit: { amount, isCrypto in
                    print("🚀 [SetAmountView] ========== AMOUNT SUBMISSION START ==========")
                    print("💰 [SetAmountView] onSubmit called with:")
                    print("   💰 Raw amount: \(amount)")
                    print("   🪙 isCrypto: \(isCrypto)")
                    print("   📊 satsToEurRate: \(satsToEurRate)")
                    print("   📊 btcToEurRate: \(btcToEurRate)")
                    print("   🔍 amount type: \(type(of: amount))")
                    print("   🔍 amount == 0? \(amount == 0)")
                    print("   🔍 Raw amount bytes: \(String(format: "%.20f", amount))")
                    
                    if amount == 0 {
                        print("❌ [SetAmountView] 🚨 CRITICAL: amount parameter is 0!")
                        print("❌ [SetAmountView] This will cause btcAmount to be 0 and lead to 'invalid amount: 0 sats'")
                    }
                    
                    let btc: Double
                    let eur: Double
                    if isCrypto {
                        // amount is in BTC
                        btc = amount
                        eur = amount * btcToEurRate
                        print("🪙 [SetAmountView] BTC PATH:")
                        print("   ₿ BTC: \(btc)")
                        print("   💶 EUR: \(eur)")
                        print("   🧮 Calculation: \(btc) BTC * \(btcToEurRate) rate = \(eur) EUR")
                        
                        if btc == 0 {
                            print("❌ [SetAmountView] 🚨 CRITICAL: btc calculated as 0!")
                            print("❌ [SetAmountView] This will cause 'invalid amount: 0 sats' in ConfirmTransactionView")
                        }
                    } else {
                        // amount is in EUR
                        eur = amount
                        // Ensure we never divide by zero
                        let safeRate = btcToEurRate > 0 ? btcToEurRate : 50000.0
                        btc = amount / safeRate
                        print("💶 [SetAmountView] EUR PATH:")
                        print("   💶 EUR: \(eur)")
                        print("   ₿ BTC: \(btc)")
                        print("   🧮 Calculation: \(eur) EUR / \(safeRate) rate = \(btc) BTC")
                        if btcToEurRate == 0 {
                            print("⚠️ [SetAmountView] Exchange rate was 0, using fallback rate: \(safeRate)")
                        }
                        
                        if btc == 0 {
                            print("❌ [SetAmountView] 🚨 CRITICAL: btc calculated as 0!")
                            print("❌ [SetAmountView] This will cause 'invalid amount: 0 sats' in ConfirmTransactionView")
                            print("❌ [SetAmountView] eur: \(eur)")
                            print("❌ [SetAmountView] btcToEurRate: \(btcToEurRate)")
                            print("❌ [SetAmountView] btc: \(btc)")
                        }
                    }
                    
                    print("📦 [SetAmountView] Setting final values:")
                    print("   ₿ btcAmount will be: \(btc)")
                    print("   💶 eurAmount will be: \(eur)")
                    print("   🔍 btc == 0? \(btc == 0)")
                    print("   🔍 eur == 0? \(eur == 0)")
                    
                    // Store transaction data in WalletStateManager for reliable access
                    walletState.setPendingTransactionData(
                        btcAmount: btc,
                        eurAmount: eur,
                        recipientAddress: recipientAddress
                    )
                    
                    print("📦 [SetAmountView] Transaction data stored in WalletStateManager")
                    
                    navigateToConfirm = true
                    print("📦 [SetAmountView] navigateToConfirm set to: \(navigateToConfirm)")
                    
                    print("✅ [SetAmountView] ========== AMOUNT SUBMISSION END ==========")
                },
                onClose: {
                    navigation.isSendViewPresented = false
                }
            )
            .task {
                // Fetch BTC price
                print("🔄 [SetAmountView] Fetching exchange rates...")
                let fetchedBtcToEurRate = await fetchPrice()
                
                print("📊 [SetAmountView] BTC to EUR rate: \(fetchedBtcToEurRate)")
                
                // Get cached balance and fee rates (no network call needed for cached data)
                let _ = await walletState.getBalance(forceRefresh: false)
                let _ = await walletState.getFeeRates(forceRefresh: false)
                print("💰 [SetAmountView] Available balance: \(walletState.availableBalance) sats")
                print("⚡ [SetAmountView] Fee rates: \(walletState.feeRates.defaultFee) sat/vB")
                
                await MainActor.run {
                    // Ensure we have a valid exchange rate
                    if fetchedBtcToEurRate > 0 {
                        btcToEurRate = fetchedBtcToEurRate
                        satsToEurRate = fetchedBtcToEurRate / 100_000_000
                    } else {
                        // Keep the default fallback values
                        print("⚠️ [SetAmountView] Using fallback exchange rate")
                    }
                }
            }

            NavigationLink(destination: ConfirmTransactionView(), isActive: $navigateToConfirm) {
                EmptyView()
            }
            .hidden()
            .onChange(of: navigateToConfirm) { newValue in
                if newValue {
                    print("🚀 [SetAmountView] Navigation triggered to ConfirmTransactionView")
                    print("   📦 Using transaction data from WalletStateManager")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers
    private func formatSats(_ sats: UInt64) -> String {
        return String(sats)
    }
    
    private func fetchPrice() async -> Double {
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { 
            print("❌ [SetAmountView] Invalid URL for price fetch")
            return 50000.0 // Default fallback price
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any], let eur = dict["EUR"] as? Double {
                print("✅ [SetAmountView] Fetched BTC price: €\(eur)")
                return eur
            }
        } catch {
            print("❌ [SetAmountView] Price fetch failed: \(error)")
        }
        // Return a reasonable default price instead of 0
        print("⚠️ [SetAmountView] Using fallback BTC price: €50000")
        return 50000.0 // Reasonable fallback price to prevent division by zero
    }
}
