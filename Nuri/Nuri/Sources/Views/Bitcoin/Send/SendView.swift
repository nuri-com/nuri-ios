import SwiftUI
// CodeScanner temporarily disabled while we stabilise build.

struct SendView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation

    var body: some View {
        GeometryReader { proxy in
            Color.black.opacity(0.95) // Placeholder for camera preview
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                    Spacer()
                        .frame(width: proxy.size.width * 0.7)
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                }
                .frame(height: proxy.size.width * 0.7)
                Rectangle()
                    .fill(Color.black.opacity(0.4))
            }
            .ignoresSafeArea()
            VStack {
                Text("Scan a bitcoin or lightning QR code")
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 100)
                Spacer()
                Spacer()
                Spacer()
                Spacer()
                Spacer()
                NavigationLink("Paste from Clipboard") {
                    SetAmountView()
                }
                .buttonStyle(ProminentButtonStyle())
            }
            .padding()
            VStack(spacing: 0) {
                NuriHeader<AnyView, AnyView>.logo(
                    title: "Send Bitcoin",
                    onClose: { navigation.isSendViewPresented = false }
                )
                Spacer()
            }
        }
    }

    // Scanner temporarily disabled
    private func handleScanPlaceholder() {}
}

#Preview {
    Text("Test")
        .sheet(isPresented: .constant(true)) {
            SendView()
        }
}
