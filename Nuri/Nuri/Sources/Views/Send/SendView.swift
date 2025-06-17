import SwiftUI
import CodeScanner

struct SendView: View {

    @Binding var isPresented: Bool

    var body: some View {
        GeometryReader { proxy in
            CodeScannerView(codeTypes: [.qr], simulatedData: "Cim Topal\ncimtopal@gmail.com", completion: handleScan)
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
            ZStack {
                Text("Send Bitcoin")
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        isPresented.toggle()
                    }
                }
            }
            .padding()
            .font(.headline)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color.white)
        }
    }

    private func handleScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            if BitcoinAddressValidator().isValid(address: result.string) {
                print("✅ Scanning result is valid: \(result.string)")
            } else {
                print("❌ Scanning result is not valid bitcoin address: \(result.string)")
            }
        case .failure(let error):
            print("❌ Scanning failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SendView(isPresented: .constant(true))
}
