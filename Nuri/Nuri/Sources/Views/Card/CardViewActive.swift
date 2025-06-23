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

                Image("card-flattend")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 256)
                    .padding(.bottom, 30)

                if showCardDetails {
                    CardDetailsView()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.bottom, 30)
                }

                // Action icons
                HStack(spacing: 32) {
                    SmallIconButton(icon: "eye_hidden", title: "Details") {
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Card Details")
                .font(.custom("Inter", size: 16).weight(.medium))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Card Number")
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "#6D6D86"))
                    Spacer()
                    Text("4321 5678 9012 3456")
                        .font(.custom("Inter", size: 16).weight(.semibold))
                }
                HStack {
                    Text("Expiry")
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "#6D6D86"))
                    Spacer()
                    Text("12/28")
                        .font(.custom("Inter", size: 16).weight(.semibold))
                }
                HStack {
                    Text("CVV")
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "#6D6D86"))
                    Spacer()
                    Text("123")
                        .font(.custom("Inter", size: 16).weight(.semibold))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 8)
        .padding(.horizontal, 24)
    }
}

#if DEBUG
#Preview {
    CardViewActive()
}
#endif 