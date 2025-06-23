import SwiftUI

struct CardViewActive: View {
    @State private var isTransactionsPresented = false
    @State private var showCardDetails = false

    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                topNavigationBar()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    .padding(.top, 44)

                // Card balance
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Text("€")
                            .font(.system(size: 40, weight: .semibold))
                        Text("1,337.00")
                            .font(.system(size: 40, weight: .semibold))
                    }
                    .foregroundColor(Color("PrimaryNuriBlack"))

                    Text("Available Balance")
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "#6D6D86"))
                }
                .padding(.bottom, 30)

                if showCardDetails {
                    CardDetailsView()
                        .transition(.opacity)
                        .padding(.bottom, 30)
                } else {
                    Image("card-flattend")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 256)
                        .padding(.bottom, 30)
                }

                // Action icons
                HStack(spacing: 32) {
                    SmallIconButton(icon: showCardDetails ? "eye_hidden" : "eye_hidden", title: "Details") {
                        withAnimation(.easeInOut) {
                            showCardDetails.toggle()
                        }
                    }
                    SmallIconButton(icon: "lock_open", title: "Freeze") {
                        // freeze card
                    }
                    SmallIconButton(icon: "money_topup", title: "Top-Up") {
                        // top up
                    }
                }
                .padding(.bottom, 30)

                // Apple wallet button
                Button(action: {
                    // add to wallet
                }) {
                    HStack(spacing: 8) {
                        Image("apple-wallet")
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text("Add to Apple Wallet")
                            .font(.brandBody)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color("PrimaryNuriBlack"))
                    .cornerRadius(100)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Link to transactions (matches BitcoinViewV2)
                Button(action: {
                    isTransactionsPresented = true
                }) {
                    Image("link-icon-to-transactions")
                        .resizable()
                        .frame(width: 24, height: 13)
                }
                .padding(.bottom, 34)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $isTransactionsPresented) {
            TransactionsView()
        }
    }

    private func topNavigationBar() -> some View {
        HStack {
            Image("nuri-logo-svg-correct")
                .resizable()
                .frame(width: 24, height: 24)

            Spacer()

            Button(action: {
                // Add money action
            }) {
                Text("+ Add Money")
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color("PrimaryNuriBlack"))
                    .cornerRadius(64)
            }
        }
    }
}

private struct SmallIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriBlack"))
            }
        }
    }
}

private struct CardDetailsView: View {
    var body: some View {
        ZStack {
            // Card background dark
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#2C232E"))
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Cardholder name
                        Text("Cim Topal")
                            .font(.custom("Inter", size: 14).weight(.semibold))
                            .foregroundColor(.white)

                        // Label
                        Text("Card number")
                            .font(.custom("Inter", size: 14))
                            .foregroundColor(.white.opacity(0.7))

                        // Number + copy
                        HStack(spacing: 4) {
                            Text("5354 5655 2079 6981")
                                .font(.custom("Inter", size: 14).weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            Button(action: {
                                UIPasteboard.general.string = "5354 5655 2079 6981"
                            }) {
                                Image("copy-icon")
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "qrcode")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.white)
                }
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expiry date")
                            .font(.custom("Inter", size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            Text("03/30")
                                .font(.custom("Inter", size: 14).weight(.semibold))
                                .foregroundColor(.white)
                            Button(action: {
                                UIPasteboard.general.string = "03/30"
                            }) {
                                Image("copy-icon")
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CVV")
                            .font(.custom("Inter", size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            Text("041")
                                .font(.custom("Inter", size: 14).weight(.semibold))
                                .foregroundColor(.white)
                            Button(action: {
                                UIPasteboard.general.string = "041"
                            }) {
                                Image("copy-icon")
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                    Spacer()
                    Image("visa-logo") // placeholder, ensure asset exists
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 12)
                }
            }
            .padding(20)
        }
        .frame(width: 256, height: 156)
    }
}

#if DEBUG
#Preview {
    CardViewActive()
}
#endif 