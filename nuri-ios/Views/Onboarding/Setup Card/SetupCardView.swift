import SwiftUI

struct SetupCardView: View {

    @ObservedObject var NFCR = NFCReader()

    var body: some View {
        Button (action: { read() }) {
            Text("Read NFC Card")
        }
        .onAppear {
            read()
        }
    }

    func read() {
        NFCR.read()
    }
}
