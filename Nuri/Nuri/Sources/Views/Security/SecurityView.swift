import SwiftUI
import AuthenticationServices

struct SecurityView: View {
    @State private var resultText = "Press the button to test the encrypted iCloud backup."
    @State private var isLoading = false
    private let bitcoinWalletService = BitcoinWalletService.shared
    


    var body: some View {
        Screen {
            // Header
            NuriHeader<AnyView, AnyView>.logoAndCTA(
                title: "Security",
                cta: "",
                onCTA: {}
            )
        } content: {
            Form {
                Section(header: Text("Test Results")) {
                    VStack {
                        if isLoading {
                            ProgressView("Performing test...")
                        } else {
                            ScrollView {
                                Text(resultText)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(minHeight: 150)
                }
                
                Section(header: Text("Backup & Recovery Verification")) {
                    Button(action: testDecryption) {
                        Label("Test Decrypt iCloud Backup", systemImage: "lock.open.display")
                    }
                }
            }
            .disabled(isLoading)
        }
    }
    
    private func testDecryption() {
        isLoading = true
        resultText = "Initiating decryption...\n\nPlease use Face ID / Touch ID when prompted."
        Task {
            let result = await bitcoinWalletService.testDecryptCloudBackup()
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
