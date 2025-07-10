import SwiftUI

struct SetAmountView: View {
    let recipientAddress: String
    
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletState = WalletStateManager.shared

    @State private var navigateToConfirm = false
    @State private var satsToEurRate: Double = 0
    @State private var btcToEurRate: Double = 0

    // Amounts to forward to confirmation screen  
    @State private var btcAmount: Double = 0 // Still in BTC for compatibility with ConfirmTransactionView
    @State private var eurAmount: Double = 0

    var body: some View {
        ZStack {
            AmountEntryScreen(
                title: "Confirm Amount",
                primarySymbol: "₿",
                secondarySymbol: "€",
                initialPrimaryIsCrypto: true,
                exchangeRate: $satsToEurRate,
                availableBalance: walletState.availableBalance,
                walletState: walletState,
                actionIcon: "bitcoin-circle",
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
                        // amount is in satoshis - use the current rates we have
                        let satsAmount = amount
                        btc = satsAmount / 100_000_000
                        eur = satsAmount * satsToEurRate
                        print("🪙 [SetAmountView] CRYPTO PATH:")
                        print("   💰 Sats: \(satsAmount)")
                        print("   ₿ BTC: \(btc)")
                        print("   💶 EUR: \(eur)")
                        print("   🧮 Calculation: \(satsAmount) sats / 100M = \(btc) BTC")
                        print("   🧮 Calculation: \(satsAmount) sats * \(satsToEurRate) rate = \(eur) EUR")
                        
                        if btc == 0 {
                            print("❌ [SetAmountView] 🚨 CRITICAL: btc calculated as 0!")
                            print("❌ [SetAmountView] This will cause 'invalid amount: 0 sats' in ConfirmTransactionView")
                            print("❌ [SetAmountView] satsAmount: \(satsAmount)")
                            print("❌ [SetAmountView] division result: \(satsAmount / 100_000_000)")
                        }
                    } else {
                        // amount is in EUR
                        eur = amount
                        let satsAmount = amount / satsToEurRate
                        btc = satsAmount / 100_000_000
                        print("💶 [SetAmountView] EUR PATH:")
                        print("   💶 EUR: \(eur)")
                        print("   💰 Sats: \(satsAmount)")
                        print("   ₿ BTC: \(btc)")
                        print("   🧮 Calculation: \(eur) EUR / \(satsToEurRate) rate = \(satsAmount) sats")
                        print("   🧮 Calculation: \(satsAmount) sats / 100M = \(btc) BTC")
                        
                        if btc == 0 {
                            print("❌ [SetAmountView] 🚨 CRITICAL: btc calculated as 0!")
                            print("❌ [SetAmountView] This will cause 'invalid amount: 0 sats' in ConfirmTransactionView")
                            print("❌ [SetAmountView] eur: \(eur)")
                            print("❌ [SetAmountView] satsToEurRate: \(satsToEurRate)")
                            print("❌ [SetAmountView] satsAmount: \(satsAmount)")
                            print("❌ [SetAmountView] btc calculation: \(satsAmount) / 100_000_000 = \(btc)")
                        }
                    }
                    
                    print("📦 [SetAmountView] Setting final values:")
                    print("   ₿ btcAmount will be: \(btc)")
                    print("   💶 eurAmount will be: \(eur)")
                    print("   🔍 btc == 0? \(btc == 0)")
                    print("   🔍 eur == 0? \(eur == 0)")
                    
                    btcAmount = btc
                    eurAmount = eur
                    print("📦 [SetAmountView] Values set:")
                    print("   ₿ btcAmount is now: \(btcAmount)")
                    print("   💶 eurAmount is now: \(eurAmount)")
                    
                    navigateToConfirm = true
                    print("📦 [SetAmountView] navigateToConfirm set to: \(navigateToConfirm)")
                    
                    print("✅ [SetAmountView] ========== AMOUNT SUBMISSION END ==========")
                },
                onClose: {
                    navigation.isSendViewPresented = false
                }
            )
            .task {
                // Fetch BTC price and calculate sats rate
                print("🔄 [SetAmountView] Fetching exchange rates...")
                let fetchedBtcToEurRate = await fetchPrice()
                let calculatedSatsToEurRate = fetchedBtcToEurRate / 100_000_000
                
                print("📊 [SetAmountView] BTC to EUR rate: \(fetchedBtcToEurRate)")
                print("📊 [SetAmountView] Sats to EUR rate: \(calculatedSatsToEurRate)")
                
                // Get cached balance and fee rates (no network call needed for cached data)
                let _ = await walletState.getBalance(forceRefresh: false)
                let _ = await walletState.getFeeRates(forceRefresh: false)
                print("💰 [SetAmountView] Available balance: \(walletState.availableBalance) sats")
                print("⚡ [SetAmountView] Fee rates: \(walletState.feeRates.defaultFee) sat/vB")
                
                await MainActor.run {
                    btcToEurRate = fetchedBtcToEurRate
                    satsToEurRate = calculatedSatsToEurRate
                }
            }

            NavigationLink(destination: ConfirmTransactionView(btcAmount: btcAmount, eurAmount: eurAmount, recipientAddress: recipientAddress), isActive: $navigateToConfirm) {
                EmptyView()
            }
            .hidden()
            .onChange(of: navigateToConfirm) { newValue in
                if newValue {
                    print("🚀 [SetAmountView] Navigation triggered to ConfirmTransactionView")
                    print("   ₿ btcAmount being passed: \(btcAmount)")
                    print("   💶 eurAmount being passed: \(eurAmount)")
                    print("   📍 recipientAddress: \(recipientAddress)")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers
    private func fetchPrice() async -> Double {
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { return 0 }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any], let eur = dict["EUR"] as? Double {
                return eur
            }
        } catch {
            print("Price fetch failed", error)
        }
        return 0
    }
}
