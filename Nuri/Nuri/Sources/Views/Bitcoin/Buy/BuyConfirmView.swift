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
                subtitle: "₿ \(String(amountSats)) will arrive in your wallet shortly",
                onDone: {
                    navigation.isBuyViewPresented = false
                }
            )
        }
    }
    
    private func loadBitcoinAddress() async {
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
            
            // Get Bitcoin address
            if let btcAccount = walletResponse.accounts.btc {
                // Check if already has address
                if let address = btcAccount.blockchainDepositAddress, !address.isEmpty {
                    await MainActor.run {
                        self.btcAddress = address
                    }
                } else {
                    // Need to enrich
                    print("🔄 [BuyConfirmView] Enriching BTC account...")
                    let enrichResponse = try await striga.enrichAccount(
                        EnrichAccount(accountId: btcAccount.accountId, userId: userId)
                    )
                    
                    if let address = enrichResponse.blockchainDepositAddress {
                        await MainActor.run {
                            self.btcAddress = address
                        }
                    }
                }
                print("✅ [BuyConfirmView] Bitcoin address: \(btcAddress)")
            }
        } catch {
            print("❌ [BuyConfirmView] Error loading Bitcoin address: \(error)")
        }
    }
    
    private func buyBitcoin() {
        print("🚀 [BuyConfirmView] Buy Bitcoin clicked - MOCKUP MODE")
        print("   💰 Amount: ₿ \(amountSats) sats")
        print("   💶 EUR: €\(eurAmount)")
        print("   📍 Destination: \(btcAddress)")
        print("   ⚡ Fee: €\(networkFeeEUR) (2%)")
        print("   📊 Total: €\(totalEUR)")
        
        isBuying = true
        
        // Mock the purchase - just show success after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                isBuying = false
                showSuccess = true
            }
            
            print("✅ [BuyConfirmView] MOCKUP: Purchase completed successfully")
            print("ℹ️ [BuyConfirmView] Note: This is a mockup - no actual purchase was made")
        }
    }
}

#Preview {
    BuyConfirmView(btcAmount: 0.001, eurAmount: 100)
        .environmentObject(BitcoinViewNavigation())
}