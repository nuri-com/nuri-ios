import SwiftUI

struct CardView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("card-flattend")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 256)
                .padding(.bottom, 30)
            Text("Nuri Card for Apple Pay")
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
            featureList()
                .padding(.bottom, 30)
            actionButton()
            Spacer()
        }
        .background(NuriAsset.background.swiftUIColor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image("nuri-logo-svg")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: CardViewActive()) {
                    Text("+ Get Card")
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

    private func featureList() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ListItemView(icon: "card_contactless", title: "Free Virtual Visa Card", subtitle: "100% free. No monthly fees.")
            ListItemView(icon: "bitcoin-recurring", title: "Top-Up with Bitcoin", subtitle: "Send BTC to add money.")
            ListItemView(icon: "wallet", title: "Add to Apple Wallet", subtitle: "Use Card with Tap-To-Pay")
        }
        .padding(.horizontal, 40)
    }

    private func actionButton() -> some View {
        NavigationLink(destination: CardViewActive()) {
            HStack(spacing: 8) {
                Image("card_contactless")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 24, height: 24)
                Text("Get Card")
                    .font(.brandBody)
            }
            .foregroundColor(Color("PrimaryNuriBlack"))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color("PrimaryNuriLilac"))
            .cornerRadius(100)
        }
        .padding(.horizontal, 24)
    }
}

private struct ListItemView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(icon)
                .resizable()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Inter", size: 16).weight(.regular))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                Text(subtitle)
                    .font(.custom("Inter", size: 16).weight(.regular))
                    .foregroundColor(Color(hex: "#02542d"))
            }
        }
    }
}

#if DEBUG
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView()
    }
}
#endif

// This extension can be moved to a separate file
