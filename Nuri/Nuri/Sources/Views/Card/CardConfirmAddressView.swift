import SwiftUI

struct CardConfirmAddressView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirm Address")
                .font(.brandTitle1)
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
                        .tint(Color("PrimaryNuriBlack"))
                    }
                }
                Text("Cim Topal\nObentrautstrasse 63\n10963 Berlin\nDeutschland")
                    .foregroundStyle(Color.secondary)
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.vertical, 16)
            NavigationLink("Order Card") {
                SuccessView(illustration: "Visa_on_the_way", title: "Yaay your card is on the way!", subtitle: "Just a few days for your card to reach your address, you will need to activate it before start using it. ") {

                }
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
