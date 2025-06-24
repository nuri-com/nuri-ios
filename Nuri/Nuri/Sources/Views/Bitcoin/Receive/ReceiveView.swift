import SwiftUI

struct ReceiveView: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Image("qr-code")
                Divider()
                Text("Bitcoin Address")
                    .foregroundStyle(Color.secondary)
                HStack {
                    Text("bc1q87rj40hdu23kzwyz5aq89fj84wrrf6h757r0y5kpxhnez2q8uvnq0gjqfl")
                    Image("copy-icon-black")
                }
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.vertical, 16)
            Spacer()
            NavigationLink("Buy Bitcoin") {
                BuyBitcoinView()
            }
            .buttonStyle(ProminentButtonStyle())
        }
        .padding(32)
        .background(NuriAsset.background.swiftUIColor)
        .navigationTitle("Receive Bitcoin")

    }
}
