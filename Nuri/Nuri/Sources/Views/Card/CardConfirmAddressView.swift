import SwiftUI

struct CardConfirmAddressView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirm Address")
                .font(.title)
            Text("Review your address, this is where your card will be sent.")
                .foregroundStyle(Color.secondary)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Shipping Address")
                    Spacer()
                    Button {

                    } label: {
                        Label {
                            EmptyView()
                        } icon: {
                            Image(systemName: "square.and.pencil")
                        }
                        .tint(Color.black)
                    }
                }
                Text("Cim Topal\nObentrautstrasse 63\n10963 Berlin\nDeutschland")
                    .foregroundStyle(Color.secondary)
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.vertical, 16)
            Button("Order Card") {

            }
            .buttonStyle(ProminentButtonStyle())
            Spacer()
        }
        .padding(24)
        .background(NuriAsset.background.swiftUIColor)
    }
}

#Preview {
    CardConfirmAddressView()
}
