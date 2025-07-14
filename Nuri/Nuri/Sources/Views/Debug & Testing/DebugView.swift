import SwiftUI

struct DebugView: View {
    @State private var resultText = "Press a button to run a debug action."
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    
    private let walletService = BitcoinWalletService.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Test Results")) {
                    VStack {
                        if isLoading {
                            ProgressView("Performing action...")
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
                
                Section(header: Text("Backup & Recovery")) {
                    Button(action: testDecryption) {
                        Label("Test Decrypt iCloud Backup", systemImage: "lock.open.display")
                    }
                }

                
                Section(header: Text("Danger Zone")) {
                    Button("DELETE ALL WALLET DATA", role: .destructive) {
                        showDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isLoading)
            .alert("Delete All Wallet Data?", isPresented: $showDeleteAlert) {
                Button("DELETE", role: .destructive) {
                    Task { await deleteAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the mnemonic, cached address, and all encrypted backups from this device and iCloud. This action cannot be undone. \n\nUSE FOR TESTING ONLY.")
            }
        }
    }

    private func testDecryption() {
        isLoading = true
        resultText = "Initiating decryption...\n\nPlease use Face ID / Touch ID when prompted."
        Task {
            let result = await walletService.testDecryptCloudBackup()
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
    private func deleteAllData() async {
        isLoading = true
        resultText = "Deleting all wallet data from keychains..."
        await walletService.clearAllWalletData()
        await MainActor.run {
            resultText = "✅ All wallet data has been deleted. Please restart the app to create a new wallet."
            isLoading = false
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView()
    }
}
