import SwiftUI

struct BuyBitcoinFlowView: View {
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @State private var navigateToSetAmount = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                NuriHeader<AnyView, AnyView>.logo(title: "Buy Bitcoin", onClose: {
                    navigation.isBuyViewPresented = false
                })
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#E0E0E0").opacity(0.9))
                
                Spacer()
                
                // Main content
                VStack(spacing: 24) {
                    Image("bitcoin-circle")
                        .resizable()
                        .frame(width: 120, height: 120)
                    
                    Text("Buy Bitcoin with EUR")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color("PrimaryNuriBlack"))
                    
                    Text("Purchase Bitcoin instantly using your EUR balance")
                        .font(.custom("Inter", size: 16))
                        .foregroundColor(Color(hex: "#6D6D86"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        navigateToSetAmount = true
                    }) {
                        NuriButton(icon: "bitcoin-circle", title: "Continue")
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                NavigationLink(destination: BuySetAmountView(), isActive: $navigateToSetAmount) {
                    EmptyView()
                }
                .hidden()
            }
            .background(Color(hex: "#F0F0F0"))
        }
    }
}

#Preview {
    BuyBitcoinFlowView()
        .environmentObject(BitcoinViewNavigation())
}