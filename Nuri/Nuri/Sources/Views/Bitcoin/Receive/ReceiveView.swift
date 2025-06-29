import SwiftUI

struct ReceiveView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @State private var address: String = ""
    @State private var isLoading = true

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
                            Image("qr-code")
                                .resizable()
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
            do {
                let addr = try await PortalService.shared.ensureBitcoinWallet()
                address = addr
            } catch {
                address = "Error fetching address"
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

