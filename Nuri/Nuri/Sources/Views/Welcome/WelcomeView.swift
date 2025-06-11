import SwiftUI

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
                    Button("Login with Passkey") {
                        isUserLoggedIn = true
                    }
                    .buttonStyle(ProminentButtonStyle())
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
