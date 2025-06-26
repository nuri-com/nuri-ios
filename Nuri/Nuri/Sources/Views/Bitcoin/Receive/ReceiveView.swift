import SwiftUI

struct ReceiveView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation

    private let address = "bc1q87rj40hdu23kzwyz5aq89fj84wrrf6h757r0y5kpxhnez2q8uvnq0gjqfl"

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Image("qr-code")
                        .resizable()
                        .frame(width: 200, height: 200)
                        .padding(16)
                    Spacer()
                }
                Divider()
                Text("Bitcoin Address")
                    .foregroundStyle(Color.secondary)
                HStack {
                    Text(address.withZeroWidthSpaces)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = address
                    } label: {
                        Image("copy-icon-black")
                    }
                }
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.vertical, 16)
            Button("Share") {
                
            }
            .buttonStyle(ProminentBlackButtonStyle())

            NavigationLink("Buy Bitcoin") {
                BuyBitcoinView(isPresented: $navigation.isReceiveViewPresented)
            }
            .buttonStyle(ProminentButtonStyle())
            Spacer()
        }
        .padding(32)
        .background(NuriAsset.background.swiftUIColor)
        .navigationTitle("Receive Bitcoin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button {
                    navigation.isReceiveViewPresented = false
                } label: {
                    Image("delete-close")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReceiveView()
    }
}

