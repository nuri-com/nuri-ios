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
                    Label {
                        Text("Bitcoin")
                            .font(.custom("Inter", size: 16))
                    } icon: {
                        Image("bitcoin-icon").renderingMode(.template)
                    }
                }
                Tab {
                    NavigationStack {
                        CardView()
                    }
                } label: {
                    Label {
                        Text("Card")
                            .font(.custom("Inter", size: 16))
                    } icon: {
                        Image("vector-icon-card").renderingMode(.template)
                    }
                }
                Tab {
                    NavigationStack {
                        SecurityView()
                    }
                } label: {
                    Label {
                        Text("Passkey")
                            .font(.custom("Inter", size: 16))
                    } icon: {
                        Image("passkey").renderingMode(.template)
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
