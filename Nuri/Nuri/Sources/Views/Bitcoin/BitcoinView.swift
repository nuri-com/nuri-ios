import SwiftUI

struct BitcoinView: View {

    @State var isSendViewPresented = false

    var body: some View {
        VStack {
            HStack {
                Image("card-icon")
                Spacer()
            }
            Spacer()
            HStack(spacing: 4) {
                Text("₿")
                HStack(spacing: 0) {
                    Text("0.0000")
                        .foregroundStyle(Color.secondary)
                    Text("1337 BTC")
                }
            }
            .font(.title)
            .fontWeight(.bold)
            Text("~$11.23 USD")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            HStack {
                Button("Receive") {
                }
                .buttonStyle(ProminentBlackButtonStyle())
                Button("Send") {
                    isSendViewPresented = true
                }
                .buttonStyle(ProminentButtonStyle())
            }
            Spacer()
            Button("Transactions") {}
        }
        .padding(32)
        .background(NuriAsset.background.swiftUIColor)
        .sheet(isPresented: $isSendViewPresented) {
            NavigationStack {
                SendView(isPresented: $isSendViewPresented)
            }
        }
    }
}

#Preview {
    BitcoinView()
}
