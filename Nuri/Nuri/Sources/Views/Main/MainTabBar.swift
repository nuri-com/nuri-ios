import SwiftUI

struct MainTabBar: View {
    @State private var selectedTab: SelectedTab = .bitcoin

    enum SelectedTab {
        case bitcoin
        case card
        case security
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
                Tab("Security", image: "lock") {
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
