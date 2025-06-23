import SwiftUI

struct CardViewActive: View {
    @State private var isTransactionsPresented = false

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

                // Action icons
                HStack(spacing: 32) {
                    SmallIconButton(icon: "eye_hidden", title: "Details") {
                        // details
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

#if DEBUG
#Preview {
    CardViewActive()
}
#endif 