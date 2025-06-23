import SwiftUI

struct MainTabBar: View {
    @State private var selectedTab: Tab = .bitcoin

    enum Tab {
        case bitcoin
        case card
        case passkey
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            ZStack {
                switch selectedTab {
                case .bitcoin:
                    NavigationStack { BitcoinViewV2() }
                case .card:
                    NavigationStack {
                        CardView()
                    }
                case .passkey:
                    NavigationStack { SecurityView() }
                }
            }
            Spacer(minLength: 0)

            // Custom Tab Bar
            HStack {
                TabBarItem(
                    icon: "bitcoin-icon",
                    title: "Bitcoin",
                    isSelected: selectedTab == .bitcoin,
                    action: { selectedTab = .bitcoin }
                )
                Spacer()
                TabBarItem(
                    icon: "vector-icon-card",
                    title: "Card",
                    isSelected: selectedTab == .card,
                    action: { selectedTab = .card }
                )
                Spacer()
                TabBarItem(
                    icon: "passkey",
                    title: "Passkey",
                    isSelected: selectedTab == .passkey,
                    action: { selectedTab = .passkey }
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .frame(height: 80)
            .background(Color(hex: "#F0F0F0"))

        }
        .ignoresSafeArea(.keyboard)
    }
}

private struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(height: 32)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color(hex: "#2C232E"))
            .opacity(isSelected ? 1.0 : 0.5)
            .frame(width: 75)
        }
    }
}

#Preview {
    MainTabBar()
}
