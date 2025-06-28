import SwiftUI

struct CardViewActive: View {
    @State private var isTransactionsPresented = false
    @State private var showCardDetails = false
    @State private var isLargeQRPresented = false
    @State private var showSnackbar = false
    @State private var snackbarTitle: String = ""
    @State private var snackbarDescription: String = ""

    private let btcAddress = "bc1qsmd4xz68a7fhwvhjkd0cawx4uvs9a43746xld4yh0spfmwefpr5qc9wvv6"

    private func copied(_ description: String) {
        snackbarTitle = "Copied"
        snackbarDescription = description
        withAnimation(.easeInOut) {
            showSnackbar = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut) {
                showSnackbar = false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Unified header
            NuriHeader<AnyView, AnyView>(title: "") {
                AnyView(
                    Image("HeaderLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                )
            } trailing: {
                AnyView(
                    NavigationLink(destination: EmptyView()) {
                        Text("+ Add Money")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                )
            }

            Spacer()
            NuriTitleWithSubtitle(title: "€1,337.00", subtitle: "Available Balance")
            .padding(.bottom, 30)

            if showCardDetails {
                CardMini(card: CardModel(holder: "Cim Topal", number: "5354 5655 2079 6981", expiry: "03/30", cvv: "041"), qrAddress: btcAddress, onQRTap: { isLargeQRPresented = true }, onCopy: { copied("Copied to clipboard") })
                    .transition(.opacity)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
            } else {
                NuriCardIllustration()
                    .padding(.bottom, 30)
            }

            HStack(spacing: 32) {
                NuriSmallIconToggle(isActive: $showCardDetails,
                                    label: "Details",
                                    iconActive: "eye",  // open eye
                                    iconInactive: "eye_hidden")
                SmallIconButton(icon: "lock_open", title: "Freeze") {
                }
                SmallIconButton(icon: "money_topup", title: "Top-Up") {
                }
            }
            .padding(.bottom, 30)

            Button(action: {

            }) {
                HStack(spacing: 8) {
                    Image("apple-wallet")
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text("Add to Apple Wallet")
                        .font(.brandBody)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color("PrimaryNuriBlack"))
                .cornerRadius(100)
            }
            .padding(.horizontal, 24)

            // Activate Card button
            NavigationLink(destination: ResidenceCitizenshipUSTaxView()) {
                HStack(spacing: 8) {
                    Image("head")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                        .frame(width: 24, height: 24)
                    Text("Activate Card")
                        .font(.brandBody)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color("PrimaryNuriLilac"))
                .cornerRadius(100)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            Button(action: {
                isTransactionsPresented = true
            }) {
                Image("link-icon-to-transactions")
                    .resizable()
                    .frame(width: 24, height: 13)
            }
            .padding(.bottom, 34)
            Spacer()
        }
        .background(NuriAsset.background.swiftUIColor)
        .overlay(
            VStack {
                if showSnackbar {
                    NuriSnackbar(style: .success,
                                 title: snackbarTitle,
                                 description: snackbarDescription)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
                Spacer()
            }
            .animation(.easeInOut, value: showSnackbar), alignment: .bottom)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $isTransactionsPresented) {
            TransactionsView()
        }
        .fullScreenCover(isPresented: $isLargeQRPresented) {
            GeometryReader { geo in
                VStack(spacing: 24) {
                    Spacer()
                    QRCodeImage(text: btcAddress)
                        .frame(width: min(geo.size.width, geo.size.height) * 0.8,
                               height: min(geo.size.width, geo.size.height) * 0.8)
                        .onAppear { UIPasteboard.general.string = btcAddress }
                        .onTapGesture { isLargeQRPresented = false }
                    Text("Bitcoin address copied to clipboard")
                        .font(.headline)
                        .padding()
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.white.opacity(0.95).ignoresSafeArea())
            }
        }
    }
}

// MARK: - Card detail components

private enum CardTextStyle {
    case label, value, name
    var font: Font {
        switch self {
        case .label: return .custom("Inter", size: 16)
        case .value: return .custom("Inter", size: 16).weight(.semibold)
        case .name:  return .custom("Inter", size: 16).weight(.semibold)
        }
    }
}

private extension Text {
    func cardStyle(_ style: CardTextStyle) -> some View {
        self.font(style.font).foregroundColor(.white)
    }
}

private struct ValueWithCopy: View {
    let text: String
    let style: CardTextStyle
    let onCopy: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .cardStyle(style)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
            Button(action: { UIPasteboard.general.string = text
                onCopy() }) {
                Image("copy-icon")
                    .resizable()
                    .frame(width: 14, height: 14)
            }
        }
    }
}

private struct CardModel {
    let holder: String
    let number: String
    let expiry: String
    let cvv: String
}

private struct CardMini: View {
    let card: CardModel
    let qrAddress: String
    let onQRTap: () -> Void
    let onCopy: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(card.holder).cardStyle(.name)

                Text("Card number").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                ValueWithCopy(text: card.number, style: .value, onCopy: onCopy)

                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expiry").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                        ValueWithCopy(text: card.expiry, style: .value, onCopy: onCopy)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                        ValueWithCopy(text: card.cvv, style: .value, onCopy: onCopy)
                    }
                }
            }
            Spacer(minLength: 12)
            QRCodeImage(text: qrAddress)
                .frame(width: 48, height: 48)
                .onTapGesture { onQRTap() }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#2C232E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .aspectRatio(257/163, contentMode: .fit)
        .frame(minHeight: 196)
    }
}

private struct SmallIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriBlack"))
            }
        }
    }
}

#if DEBUG
#Preview {
    CardViewActive()
}
#endif
