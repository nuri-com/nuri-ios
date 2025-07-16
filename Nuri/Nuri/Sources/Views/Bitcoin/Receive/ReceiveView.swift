import SwiftUI

struct ReceiveView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @State private var address: String = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>.logo(
                title: "Receive Bitcoin",
                onClose: { navigation.isReceiveViewPresented = false }
            )

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    // Show QR only if we have a plausible BTC address
                    if Self.isBitcoinAddress(address) {
                        HStack {
                            Spacer()
                            QRCodeImage(text: address)
                                .frame(width: 200, height: 200)
                                .padding(16)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(width: 50, height: 50)
                                .padding(16)
                            Spacer()
                        }
                    }
                    Divider()
                    Text("Bitcoin Address")
                        .foregroundStyle(Color.secondary)
                    HStack {
                        if isLoading {
                            ProgressView()
                        } else if Self.isBitcoinAddress(address) {
                            Text(address.withZeroWidthSpaces)
                        } else {
                            Text("Address not available yet")
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        if Self.isBitcoinAddress(address) {
                            Button {
                                UIPasteboard.general.string = address
                            } label: {
                                Image("copy-icon-black")
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.vertical, 16)

                Button("Share") {
                    
                }
                .buttonStyle(ProminentBlackButtonStyle())

                NavigationLink("Buy Bitcoin") {
                    BuyBitcoinView(isPresented: $navigation.isReceiveViewPresented)
                }
                .buttonStyle(ProminentButtonStyle())
                Spacer()
            }
            .padding(32)
        }
        .background(NuriAsset.background.swiftUIColor)
        .task {
            await loadWalletData()
        }
    }
    
    private func loadWalletData() async {
        print("📱 [ReceiveView] Loading wallet data...")
        await MainActor.run {
            isLoading = true
        }
        
        let walletService = BitcoinWalletService.shared
        
        // Ensure wallet is initialized first
        if !walletService.hasWallet() {
            print("⚠️ [ReceiveView] Wallet not initialized, initializing now...")
            walletService.initializeWalletOnAppStart()
            
            // Wait for initialization
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        await MainActor.run {
            // Get current address - this should work without Face ID
            if let addr = walletService.currentAddress() {
                print("✅ [ReceiveView] Got address: \(addr)")
                address = addr
            } else {
                print("❌ [ReceiveView] Failed to get address")
                address = ""
            }
            
            isLoading = false
        }
    }

    // MARK: - Helpers
    private static func isBitcoinAddress(_ address: String) -> Bool {
        let lower = address.lowercased()
        return lower.hasPrefix("bc1") || lower.hasPrefix("tb1") || lower.hasPrefix("1") || lower.hasPrefix("3")
    }
}

#Preview {
    NavigationStack {
        ReceiveView()
    }
}

