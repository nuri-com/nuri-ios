import SwiftUI
import StrigaAPI

struct BuyConfirmView: View {
    let btcAmount: Double
    let eurAmount: Double
    
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletState = WalletStateManager.shared
    
    @State private var isBuying = false
    @State private var showSuccess = false
    @State private var btcAddress = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var eurAccountId = ""
    @State private var btcAccountId = ""
    
    private let striga = StrigaService.shared
    
    // Calculate network fee as 2% of EUR amount
    private var networkFeeEUR: Double {
        return eurAmount * 0.02
    }
    
    private var totalEUR: Double {
        return eurAmount + networkFeeEUR
    }
    
    private var amountSats: UInt64 {
        return UInt64(btcAmount * 100_000_000)
    }
    
    var body: some View {
        Screen {
            NuriHeader<AnyView, AnyView>.backAndClose(
                title: "Confirm Purchase",
                onBack: { dismiss() },
                onClose: { navigation.isBuyViewPresented = false }
            )
        } content: {
            VStack(spacing: 16) {
                // Amount display - EUR on top, BTC below
                VStack(spacing: 4) {
                    // EUR amount
                    HStack(spacing: 4) {
                        Text("€")
                            .font(.system(size: 40, weight: .semibold))
                        Text(String(format: "%.2f", totalEUR))
                            .font(.system(size: 40, weight: .semibold))
                    }
                    
                    // Bitcoin amount
                    HStack(spacing: 4) {
                        Text("₿")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Text(String(amountSats))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                }
                
                // Details card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient")
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundColor(Color("PrimaryNuriBlack"))
                    
                    if btcAddress.isEmpty {
                        Text("Loading wallet address...")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("TextSecondary"))
                    } else {
                        Text(btcAddress)
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                            .textSelection(.enabled)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Buy")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                        Text("₿ \(String(amountSats))")
                            .font(.custom("Inter", size: 16).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    
                    HStack {
                        Text("From Nuri Card")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("TextSecondary"))
                        Spacer()
                        Text(String(format: "%.2f EUR", eurAmount))
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Network Fee")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                        Text(String(format: "€ %.2f", networkFeeEUR))
                            .font(.custom("Inter", size: 16).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    
                    HStack {
                        Spacer()
                        Text("2% processing fee")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("TextSecondary"))
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.vertical, 16)
                
                Spacer()
                
                // Fee calculation display (above button)
                Text("€ \(String(format: "%.2f", eurAmount)) Amount + € \(String(format: "%.2f", networkFeeEUR)) Fee = € \(String(format: "%.2f", totalEUR))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                
                Button(action: buyBitcoin) {
                    if isBuying {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("Processing...")
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        NuriButton(
                            icon: "bitcoin-circle",
                            title: "Buy Bitcoin",
                            style: .primary
                        )
                    }
                }
                .disabled(isBuying || btcAddress.isEmpty)
            }
            .padding(32)
        }
        .task {
            await loadBitcoinAddress()
        }
        .sheet(isPresented: $showSuccess) {
            SuccessView(
                illustration: "bitcoin-sent",
                title: "Bitcoin purchased!",
                subtitle: "₿ \(String(amountSats)) has been purchased in your Striga wallet",
                onDone: {
                    navigation.isBuyViewPresented = false
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadBitcoinAddress() async {
        // Get the user's actual testnet wallet address from the app
        if let appWalletAddress = BitcoinWalletService.shared.currentAddress() {
            await MainActor.run {
                self.btcAddress = appWalletAddress
            }
            print("✅ [BuyConfirmView] Using app's testnet wallet address: \(appWalletAddress)")
        } else {
            print("❌ [BuyConfirmView] Could not get wallet address from app")
            await MainActor.run {
                self.errorMessage = "Unable to get your wallet address. Please try again."
                self.showError = true
            }
        }
        
        // Also load the Striga account IDs for the swap
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                print("❌ [BuyConfirmView] Missing user or card ID")
                return
            }
            
            // Get card to find the linked wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            // Get wallet details
            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
            
            // Store account IDs for swap
            if let eurAccount = walletResponse.accounts.eur {
                await MainActor.run {
                    self.eurAccountId = eurAccount.accountId
                }
                print("✅ [BuyConfirmView] EUR account ID: \(eurAccount.accountId)")
            }
            
            if let btcAccount = walletResponse.accounts.btc {
                await MainActor.run {
                    self.btcAccountId = btcAccount.accountId
                }
                print("✅ [BuyConfirmView] BTC account ID: \(btcAccount.accountId)")
                
                // Ensure BTC account is enriched (has blockchain address)
                if btcAccount.blockchainDepositAddress == nil || btcAccount.blockchainDepositAddress!.isEmpty {
                    print("🔄 [BuyConfirmView] Enriching BTC account...")
                    _ = try await striga.enrichAccount(
                        EnrichAccount(accountId: btcAccount.accountId, userId: userId)
                    )
                    print("✅ [BuyConfirmView] BTC account enriched")
                }
            }
        } catch {
            print("❌ [BuyConfirmView] Error loading account IDs: \(error)")
        }
    }
    
    private func buyBitcoin() {
        print("🚀 [BuyConfirmView] Starting real EUR to BTC swap on testnet")
        print("   💰 Amount: ₿ \(amountSats) sats")
        print("   💶 EUR: €\(eurAmount)")
        print("   📍 Destination: \(btcAddress)")
        print("   ⚡ Fee: €\(networkFeeEUR) (2%)")
        print("   📊 Total: €\(totalEUR)")
        
        isBuying = true
        
        Task {
            do {
                guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId else {
                    throw NSError(domain: "BuyConfirmView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing user ID"])
                }
                
                guard !eurAccountId.isEmpty && !btcAccountId.isEmpty else {
                    throw NSError(domain: "BuyConfirmView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing account IDs"])
                }
                
                // Convert EUR amount to cents (Striga uses smallest units)
                let eurAmountCents = Int(totalEUR * 100)
                
                print("🔄 [BuyConfirmView] Step 1: Performing EUR to BTC swap...")
                print("   💶 Source: EUR account \(eurAccountId)")
                print("   ₿ Destination: BTC account \(btcAccountId)")
                print("   💰 Amount: \(eurAmountCents) cents")
                
                // Perform the swap from EUR to BTC
                let swapResponse = try await striga.swapCurrencies(.init(
                    userId: userId,
                    sourceAccountId: eurAccountId,
                    destinationAccountId: btcAccountId,
                    amount: String(eurAmountCents),
                    ip: "127.0.0.1"
                ))
                
                print("✅ [BuyConfirmView] Swap successful!")
                print("   🆔 Swap ID: \(swapResponse.id)")
                print("   📊 Status: \(swapResponse.status)")
                print("   💶 EUR used: \(swapResponse.sourceAmount) cents (\(swapResponse.order?.debit.amountFloat ?? "0") EUR)")
                print("   ₿ BTC received: \(swapResponse.destinationAmount) satoshis (\(swapResponse.order?.credit.amountFloat ?? "0") BTC)")
                print("   📈 Exchange rate: \(swapResponse.exchangeRate) EUR/BTC")
                
                // Wait a moment for the swap to process
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Step 2: BTC is now in user's Striga BTC wallet
                print("🎉 [BuyConfirmView] Purchase completed successfully!")
                print("   ✅ EUR to BTC swap executed on Striga testnet")
                print("   💶 EUR spent: \(swapResponse.order?.debit.amountFloat ?? "0") EUR")
                print("   ₿ BTC received: \(swapResponse.order?.credit.amountFloat ?? "0") BTC (\(swapResponse.destinationAmount) sats)")
                print("   📍 BTC is now in your Striga BTC wallet")
                print("")
                print("ℹ️ [BuyConfirmView] Next step in production:")
                print("   • User would withdraw BTC from Striga to: \(btcAddress)")
                print("   • This can be done via Striga's web interface or API")
                print("   • For testnet demonstration, the BTC remains in Striga wallet")
                
                await MainActor.run {
                    isBuying = false
                    showSuccess = true
                }
                
                // Refresh balance after successful purchase
                await walletState.getBalance(forceRefresh: true)
                
            } catch {
                print("❌ [BuyConfirmView] Error during purchase: \(error)")
                await MainActor.run {
                    isBuying = false
                    errorMessage = "Failed to complete purchase: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    BuyConfirmView(btcAmount: 0.001, eurAmount: 100)
        .environmentObject(BitcoinViewNavigation())
}