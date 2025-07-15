import SwiftUI
import UIKit
import AuthenticationServices
import BitcoinDevKit

struct WelcomeView: View {

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false
    @State private var showError = false
    @State private var errorMessage = ""

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
                    
                    Button("Login with Passkey") {
                        mockPasskeyLogin()
                    }
                    .buttonStyle(ProminentButtonStyle())
                }
                .padding(32)
            }
            .background(NuriAsset.brandOrange.swiftUIColor)
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions
    
    private func mockPasskeyLogin() {
        print("🔐 [WelcomeView] Mock passkey login initiated")
        print("⚡ [WelcomeView] Skipping authentication and going directly to app")
        
        // Mock login - directly set user as logged in without any authentication
        self.isUserLoggedIn = true
        // No need to dismiss - NuriApp will automatically switch views
    }
    
    // MARK: - View Helpers
}

#Preview {
    WelcomeView()
}

