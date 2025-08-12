import SwiftUI

struct BuyBitcoinFlowView: View {
    @EnvironmentObject var navigation: BitcoinViewNavigation
    
    var body: some View {
        NavigationStack {
            BuySetAmountView()
        }
    }
}

#Preview {
    BuyBitcoinFlowView()
        .environmentObject(BitcoinViewNavigation())
}