import SwiftUI

struct SetAmountView: View {
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToConfirm = false

    var body: some View {
        ZStack {
            AmountEntryScreen(
                title: "Confirm Amount",
                primarySymbol: "₿",
                secondarySymbol: "€",
                initialPrimaryIsCrypto: true,
                exchangeRate: 0, // could be updated later
                actionIcon: "bitcoin-circle",
                actionTitle: "Confirm Amount",
                onSubmit: { _, _ in
                    navigateToConfirm = true
                },
                onClose: {
                    navigation.isSendViewPresented = false
                }
            )

            NavigationLink(destination: ConfirmTransactionView(), isActive: $navigateToConfirm) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
