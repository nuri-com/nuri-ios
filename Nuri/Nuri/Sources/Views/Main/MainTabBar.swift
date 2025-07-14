import SwiftUI

struct MainTabBar: View {
    @State private var selectedTab: SelectedTab = .passkey

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
                Tab("Keys", image: "passkey") {
                    NavigationStack {
                        SecurityView()
                    }
                }
            }
            .accentColor(Color("PrimaryNuriBlack"))
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    MainTabBar()
}
