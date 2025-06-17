import SwiftUI

struct MainTabBar: View {

    var body: some View {
        TabView {
            Tab("Bitcoin", image: "bitcoin-icon") {
                NavigationStack {
                    BitcoinView()
                }
            }
            Tab("Card", image: "card-icon") {
                EmptyView()
            }
            Tab("Security", image: "security-icon") {
                EmptyView()
            }
        }
    }
}

#Preview {
    MainTabBar()
}
