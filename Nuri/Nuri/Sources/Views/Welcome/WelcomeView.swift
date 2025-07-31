import SwiftUI
import UIKit
import AuthenticationServices
import BitcoinDevKit

struct WelcomeView: View {

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack {
                    Spacer()
                    Text("Your Biometrics. Your Bitcoin. Your Money.")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(40)
                        .multilineTextAlignment(.center)
                    Image("intro")
                        .resizable()
                        .scaleEffect(1.1)
                        .offset(y: 20)
                }
                VStack {
                    Spacer()
                    
                    // Primary button - Create Wallet
                    Button(action: {
                        print("\n🆕 ===== CREATE WALLET STARTED =====")
                        print("👆 [WelcomeView] User tapped 'Create Wallet' button")
                        Task {
                            await createNewPasskey()
                        }
                    }) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Create Wallet")
                        }
                    }
                    .buttonStyle(ProminentButtonStyle())
                    .disabled(isAuthenticating)
                    
                    // Secondary button - Recover Wallet
                    Button(action: {
                        print("\n🔐 ===== RECOVER WALLET STARTED =====")
                        print("👆 [WelcomeView] User tapped 'Recover Wallet' button")
                        Task {
                            await authenticateWithPasskey()
                        }
                    }) {
                        Text("Recover Wallet")
                            .foregroundColor(.white)
                            .underline()
                    }
                    .disabled(isAuthenticating)
                    .padding(.top, 16)
                }
                .padding(32)
            }
            .background(NuriAsset.brandOrange.swiftUIColor)
            .onAppear {
                Log.ui.info("===== WELCOME VIEW APPEARED =====", metadata: [
                    "isUserLoggedIn": isUserLoggedIn,
                    "isAuthenticating": isAuthenticating
                ])
                Log.ui.info("Ready to authenticate with passkeys")
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions
    
    @MainActor
    private func authenticateWithPasskey() async {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        print("🔐 [WelcomeView] Starting passkey authentication...")
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                print("❌ [WelcomeView] Could not find key window")
                throw PasskeyError.invalidURL
            }
            
            print("🪟 [WelcomeView] Found window for passkey presentation")
            let result = try await PasskeyAuthenticationService.shared.authenticateWithPasskey(presentationAnchor: window)
            
            if result.verified {
                print("✅ [WelcomeView] Passkey authentication successful")
                print("👤 [WelcomeView] Username: \(result.username ?? "anonymous")")
                print("🎭 [WelcomeView] Is Anonymous: \(result.isAnonymous)")
                
                // Successfully authenticated
                self.isUserLoggedIn = true
            } else {
                throw PasskeyError.serverError
            }
        } catch PasskeyError.noPasskeysFound {
            // No passkeys found
            print("⚠️ [WelcomeView] No passkeys found")
            errorMessage = "No wallet found. Please create a new wallet first."
            showError = true
        } catch {
            print("❌ [WelcomeView] Passkey authentication failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    @MainActor
    private func createNewPasskey() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        print("🔑 [WelcomeView] Creating new passkey...")
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                print("❌ [WelcomeView] Could not find key window for passkey creation")
                throw PasskeyError.invalidURL
            }
            
            // Create anonymous passkey
            let result = try await PasskeyAuthenticationService.shared.createPasskey(presentationAnchor: window)
            
            if result.verified {
                print("✅ [WelcomeView] Passkey created successfully")
                print("👤 [WelcomeView] Username: \(result.username ?? "anonymous")")
                
                // Successfully created and authenticated
                self.isUserLoggedIn = true
            } else {
                throw PasskeyError.serverError
            }
        } catch {
            print("❌ [WelcomeView] Passkey creation failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - View Helpers
}

#Preview {
    WelcomeView()
}

