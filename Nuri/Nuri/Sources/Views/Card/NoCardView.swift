import SwiftUI
import Combine
import UIKit

struct NoCardView: View {

    @EnvironmentObject var navigation: CreateCardNavigation

    var body: some View {
        Screen {
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
                    Button(action: {
                        navigation.isPresented = true
                    }) {
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
        } content: {
            VStack(spacing: 0) {
                NuriCardIllustration()
                    .padding(.bottom, 24)
                NuriTitleWithSubtitle(title: "Nuri Card for Apple Pay", subtitle: "")
                featureList()
                    .padding(.top, -6)
                    .padding(.bottom, 24)
                Button(action: {
                    navigation.isPresented = true
                }) {
                    NuriButton(icon: "card_contactless", title: "Get Card", style: .primary)
                }
            }
            .padding(.top, 30)
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
        }
    }

    private func featureList() -> some View {
        VStack(spacing: 0) {
            NuriMenuRow(icon: "card_contactless",
                        title: "Free Virtual Visa Card",
                        subtitle: "No monthly fees.")

            NuriMenuRow(icon: "bitcoin-recurring",
                        title: "Top-Up with Bitcoin",
                        subtitle: "Send BTC to add money.")

            NuriMenuRow(icon: "wallet",
                        title: "Add to Apple Wallet",
                        subtitle: "Use with Tap-To-Pay")
        }
    }
}

#if DEBUG
struct NoCardView_Previews: PreviewProvider {
    static var previews: some View {
        NoCardView()
    }
}
#endif
