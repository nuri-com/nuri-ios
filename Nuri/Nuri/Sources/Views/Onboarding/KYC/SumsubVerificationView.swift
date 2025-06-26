import SwiftUI

/// Simple screen that starts the Sumsub document upload + liveness flow.
struct SumsubVerificationView: View {
    @Environment(\.dismiss) private var dismiss

    // Sandbox access token provided by Sumsub (public, safe to embed in client for sandbox only).
    private let sandboxAccessToken = "sbx:KPfLzjksGrj7tvuDGBo5vb4m.m9h1nVQGvq4HlLuCnWKqLhgoW1QJ9wbn"

    @State private var showSDK = false
    @State private var verificationResult: Bool? = nil

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

                Button("Start verification") { showSDK = true }
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

    private var sdkView: some View {
        SumsubView(accessToken: sandboxAccessToken) { approved in
            verificationResult = approved
            dismiss()
        }
        .ignoresSafeArea()
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