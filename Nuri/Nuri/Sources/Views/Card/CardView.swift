import SwiftUI

struct CardView: View {

    var body: some View {
        VStack {
            HStack {
                Image("card-icon")
                Spacer()
            }
            Spacer()
            Image("card")
                .shadow(radius: 20)
            Text("Get Your Bitcoin Card.")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("✔️ 9,99 EUR/month")
                    Text("✔️ Free VISA / Mastercard")
                    Text("✔️ Bitcoin Hardware Wallet")
                }
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                Spacer()
            }
            Spacer()
            NavigationLink("Buy with Apple Pay") {
                CardConfirmAddressView()
            }
            .buttonStyle(ProminentBlackButtonStyle())
        }
        .padding(32)
        .background(NuriAsset.background.swiftUIColor)
    }
}

#Preview {
    NavigationStack {
        CardView()
    }
}
