import SwiftUI

/// Simple screen that starts the Sumsub document upload + liveness flow.
struct SumsubVerificationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showSDK = false
    @State private var accessToken: String? = nil
    @State private var verificationResult: Bool? = nil

    private func startVerification() {
        SumsubService.shared.fetchAccessToken { token in
            accessToken = token
            showSDK = token != nil
        }
    }

    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            VStack(spacing: 24) {
                topBar
                Text("Verify your identity")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                Text("Upload your ID document and complete a quick liveness check.")
                    .font(.brandBody)
                    .foregroundColor(Color("TextSecondary"))
                    .padding(.horizontal, 24)

                Spacer()

                NavigationLink(destination: sdkView, isActive: $showSDK) {
                    EmptyView()
                }.hidden()

                Button("Start verification") { startVerification() }
                    .font(.brandBody)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color("PrimaryNuriLilac"))
                    .cornerRadius(100)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder private var sdkView: some View {
        if let token = accessToken {
            SumsubView(accessToken: token) { approved in
                verificationResult = approved
                dismiss()
            }
            .ignoresSafeArea()
        } else {
            ProgressView()
                .onAppear { startVerification() }
                .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image("arrow-back")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color("PrimaryNuriBlack"))
            }
            Spacer()
            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 44)
    }
} 