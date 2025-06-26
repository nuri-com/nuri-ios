import SwiftUI

struct MainTabBar: View {
    @State private var selectedTab: SelectedTab = .bitcoin

    enum SelectedTab {
        case bitcoin
        case card
        case passkey
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                Tab("Bitcoin", image: "bitcoin-icon") {
                    NavigationStack {
                        BitcoinView()
                    }
                }
                Tab("Card", image: "vector-icon-card") {
                    NavigationStack {
                        CardView()
                    }
                }
                Tab("Passkey", image: "passkey") {
                    NavigationStack {
                        SecurityView()
                    }
                }
            }
            .tint(.black)
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    MainTabBar()
}
