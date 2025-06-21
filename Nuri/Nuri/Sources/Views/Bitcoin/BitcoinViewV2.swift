import SwiftUI

struct BitcoinViewV2: View {
    @State private var isSendViewPresented = false

    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").edgesIgnoringSafeArea(.all)
            VStack {
                TopNavigationBar()
                Spacer()
                AmountAndButtons(onSendTapped: {
                    isSendViewPresented = true
                })
                Spacer()
                Button(action: {
                    // Open transactions list
                }) {
                    Image("link-icon-to-transactions")
                        .resizable()
                        .frame(width: 24, height: 13)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 44)
            .padding(.bottom, 34)
        }
        .sheet(isPresented: $isSendViewPresented) {
            NavigationStack {
                SendView(isPresented: $isSendViewPresented)
            }
        }
    }
}

private struct TopNavigationBar: View {
    var body: some View {
        HStack {
            Image("nuri-logo-svg")
                .resizable()
                .frame(width: 24, height: 24)
            Spacer()
            Button(action: {
                // Add action for buying Bitcoin
            }) {
                Text("+Buy Bitcoin")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#2C232E"))
                    .cornerRadius(64)
            }
        }
    }
}

private struct AmountAndButtons: View {
    let onSendTapped: () -> Void

    var body: some View {
        VStack(spacing: 21) {
            VStack(spacing: 12) {
                AmountAndCurrency()
                SecondaryCurrencyAndAmount()
            }
            TwoActionButtons(onSendTapped: onSendTapped)
        }
    }
}

private struct AmountAndCurrency: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("₿")
                .font(.system(size: 40, weight: .semibold))
            HStack(spacing: 0) {
                Text("0.0000")
                    .foregroundColor(Color.gray.opacity(0.55))
                Text("1337")
            }
            .font(.system(size: 40, weight: .semibold))
        }
    }
}

private struct SecondaryCurrencyAndAmount: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("€")
            Text("11.23")
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(Color(hex: "#6D6D86"))
    }
}

private struct TwoActionButtons: View {
    let onSendTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SecondaryHalfButton(title: "Receive", icon: "bitcoin_hand", action: {})
            PrimaryHalfButton(title: "Send", icon: "qr_scan", action: onSendTapped)
        }
        .padding(.top, 12)
    }
}

private struct SecondaryHalfButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 21, height: 21)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color(hex: "#2C232E"))
            .frame(width: 131.5, height: 43)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color(hex: "#2C232E"), lineWidth: 1.4)
            )
        }
    }
}

private struct PrimaryHalfButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 23, height: 23)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color(hex: "#2C232E"))
            .frame(width: 131.5, height: 43)
            .background(Color(hex: "#BEAAFF"))
            .cornerRadius(32)
        }
    }
}

private struct BottomNavigation: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("link-icon-to-transactions")
                 .resizable()
                 .frame(width: 13, height: 24)
                 .rotationEffect(.degrees(90))

            BottomHorizontalTabs()
        }
    }
}

private struct BottomHorizontalTabs: View {
    var body: some View {
        HStack(spacing: 0) {
            TabItem(title: "Bitcoin", icon: "bitcoin-icon", isSelected: true)
            Spacer()
            TabItem(title: "Card", icon: "card-icon")
            Spacer()
            TabItem(title: "Security", icon: "security-icon")
        }
        .frame(height: 54)
    }
}

private struct TabItem: View {
    let title: String
    let icon: String
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
            Text(title)
                .font(.system(size: 12))
        }
        .foregroundColor(isSelected ? Color(hex: "#2C232E") : Color(hex: "#2C232E").opacity(0.5))
        .frame(width: 75)
    }
}


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


#Preview {
    BitcoinViewV2()
} 