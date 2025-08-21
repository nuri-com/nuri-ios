import SwiftUI

struct ReceiveView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @State private var address: String = ""
    @State private var isLoading = false
    @State private var showCopiedToast = false

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

                Button("Buy Bitcoin") {
                    // Copy address to clipboard
                    if Self.isBitcoinAddress(address) {
                        UIPasteboard.general.string = address
                        showCopiedToast = true
                        
                        // Hide toast after 2 seconds and open webview
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedToast = false
                            navigation.isBuyViewPresented = true
                        }
                    } else {
                        // If no address available, just open the webview
                        navigation.isBuyViewPresented = true
                    }
                }
                .buttonStyle(ProminentButtonStyle())
                Spacer()
            }
            .padding(32)
        }
        .background(NuriAsset.background.swiftUIColor)
        .overlay(
            Group {
                if showCopiedToast {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text("Bitcoin address copied!")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 50)
                    .animation(.easeInOut, value: showCopiedToast)
                }
            }
        )
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

