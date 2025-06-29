import SwiftUI
import UIKit

struct WelcomeView: View {

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack {
                    Spacer()
                    Text("The gateway to bitcoin and new financial opportunities.")
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
                    Button("Login with Passkey (Native)") {
                        PasskeyAuthCoordinator.shared.start { result in
                            switch result {
                            case .success:
                                DispatchQueue.main.async {
                                    isUserLoggedIn = true
                                }
                            case .failure(let error):
                                print("❌ Passkey login failed:", error)
                            }
                        }
                    }
                    .buttonStyle(ProminentButtonStyle())

                    Button("Register with Passkey") {
                        PasskeyAuthCoordinator.shared.register { result in
                            switch result {
                            case .success:
                                DispatchQueue.main.async {
                                    isUserLoggedIn = true
                                }
                            case .failure(let error):
                                print("❌ Passkey registration failed:", error)
                            }
                        }
                    }
                    .buttonStyle(ProminentBlackButtonStyle())
                }
                .padding(32)
            }
            .background(NuriAsset.brandOrange.swiftUIColor)
        }
    }
}

#Preview {
    WelcomeView()
}
