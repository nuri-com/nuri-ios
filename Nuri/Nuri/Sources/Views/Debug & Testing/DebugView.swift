import SwiftUI

struct DebugView: View {
    @State private var resultText = "Press the button to test decryption."
    @State private var isLoading = false
    private let walletService = BitcoinWalletService.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Wallet Security Debug")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            Text("This screen helps test the encrypted iCloud backup functionality.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()

            VStack {
                if isLoading {
                    ProgressView("Requesting decryption key...")
                } else {
                    ScrollView {
                        Text(resultText)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.leading)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(height: 200)

            Spacer()

            Button(action: {
                testDecryption()
            }) {
                HStack {
                    Image(systemName: "lock.open.display")
                    Text("Test Decrypt iCloud Backup")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)
        }
        .padding()
        .navigationTitle("Debug Menu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func testDecryption() {
        isLoading = true
        resultText = "Initiating decryption...\n\nPlease use Face ID / Touch ID when prompted to unlock the decryption key."
        Task {
            let result = await walletService.testDecryptCloudBackup()
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DebugView()
        }
    }
}
