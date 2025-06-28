import SwiftUI

struct CardView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Unified header
            NuriHeader<AnyView, AnyView>(title: "") {
                AnyView(
                    Image("HeaderLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                )
            } trailing: {
                AnyView(
                    NavigationLink(destination: CardViewActive()) {
                        Text("+ Get Card")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                )
            }

            VStack(spacing: 0) {
                NuriCardIllustration()
                    .padding(.bottom, 24)
                NuriTitleWithSubtitle(title: "Nuri Card for Apple Pay", subtitle: "")
                    .padding(.bottom, 8)
                featureList()
                NavigationLink(destination: CardViewActive()) {
                    NuriButton(icon: "card_contactless", title: "Get Card", style: .primary)
                }
            }
            .padding(.top, 30)
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
        }
        .background(NuriAsset.background.swiftUIColor)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func featureList() -> some View {
        VStack(spacing: 0) {
            NuriMenuRow(icon: "card_contactless",
                        title: "Free Virtual Visa Card",
                        subtitle: "100% free. No monthly fees.")

            NuriMenuRow(icon: "bitcoin-recurring",
                        title: "Top-Up with Bitcoin",
                        subtitle: "Send BTC to add money.")

            NuriMenuRow(icon: "wallet",
                        title: "Add to Apple Wallet",
                        subtitle: "Use Card with Tap-To-Pay")
        }
        .padding(.horizontal, 16)
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
