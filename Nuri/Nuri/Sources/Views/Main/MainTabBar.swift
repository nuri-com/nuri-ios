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
                Tab {
                    NavigationStack {
                        BitcoinView()
                    }
                } label: {
                    Label("Bitcoin", image: "bitcoin-icon")
                }
                Tab {
                    NavigationStack {
                        CardView()
                    }
                } label: {
                    Label("Card", image: "vector-icon-card")
                }
                Tab {
                    NavigationStack {
                        SecurityView()
                    }
                } label: {
                    Label("Passkey", image: "passkey")
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    MainTabBar()
}
