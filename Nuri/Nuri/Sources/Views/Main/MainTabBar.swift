import SwiftUI

struct MainTabBar: View {

    var body: some View {
        TabView {
            Tab("Bitcoin", image: "bitcoin-icon") {
                EmptyView()
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
