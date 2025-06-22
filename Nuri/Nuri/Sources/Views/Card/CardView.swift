import SwiftUI

struct CardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                topNavigationBar()
                
                Image("nuri-card-new")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 280)
                    .shadow(color: .black.opacity(0.25), radius: 35, x: 6, y: 6)

                Text("Nuri Card for Apple Pay")
                    .font(Font.custom("SF Pro", size: 28))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .multilineTextAlignment(.center)
                    .frame(width: 284)

                featureList()

                actionButton()
                
                Spacer() 
            }
            .padding(.horizontal, 24)
            .padding(.top, 44)
            .padding(.bottom, 34)
        }
        .background(Color(hex: "#F0F0F0").edgesIgnoringSafeArea(.all))
        .edgesIgnoringSafeArea(.bottom)
    }

    private func topNavigationBar() -> some View {
        HStack {
            Image("nuri-logo-svg-correct")
                .resizable()
                .frame(width: 24, height: 24)

            Spacer()

            Button(action: {
                // Get Card action
            }) {
                Text("+ Get Card")
                    .font(Font.custom("Inter-Medium", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("PrimaryNuriBlack"))
                    .cornerRadius(64)
            }
        }
    }

    private func featureList() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ListItemView(icon: "card_contactless", title: "Free Virtual Visa Card", subtitle: "100% free. No monthly fees.")
            ListItemView(icon: "bitcoin-icon-v2", title: "Top-Up with Bitcoin", subtitle: "Send BTC to add money.")
            ListItemView(icon: "wallet", title: "Add to Apple Wallet", subtitle: "Use Card with Tap-To-Pay")
        }
    }

    private func actionButton() -> some View {
        Button(action: {
            // Get Card action
        }) {
            HStack(spacing: 16) {
                Image("card_contactless")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 24, height: 24)
                Text("Get Card")
                    .font(Font.custom("Inter-Medium", size: 16))
            }
            .foregroundColor(Color("PrimaryNuriBlack"))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color("PrimaryNuriLilac"))
            .cornerRadius(100)
        }
    }
}

struct ListItemView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(icon)
                .resizable()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Font.custom("SF Pro", size: 17))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                Text(subtitle)
                    .font(Font.custom("SF Pro", size: 17))
                    .foregroundColor(Color(hex: "#02542d"))
            }
        }
    }
}

#Preview {
    CardView()
}
