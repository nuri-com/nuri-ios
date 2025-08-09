import SwiftUI

struct EmailConfirmationView: View {
    @State private var email: String = ""
    @State private var showNameInput = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool
    
    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            NuriHeader<AnyView, AnyView>(title: "", leading: {
                AnyView(
                    Button(action: { dismiss() }) {
                        Image("arrow-back")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(width: 32, height: 32)
                    }
                )
            }, trailing: {
                AnyView(
                    Button(action: {
                        continueToNameInput()
                    }) {
                        Text("Next")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                    .disabled(!isValidEmail)
                    .opacity(isValidEmail ? 1.0 : 0.5)
                )
            })
            .padding(.top, 10)
            
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Headline
                Text("Confirm your email")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                // Subtitle
                Text("We'll use this email for your Nuri Card account. You can edit it if needed.")
                    .font(.brandBody)
                    .foregroundColor(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, -16)
                
                // Email display field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email address")
                        .font(.custom("Inter", size: 14).weight(.medium))
                        .foregroundColor(Color("PrimaryNuriLilac"))
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color("PrimaryNuriLilac"))
                        
                        TextField("Enter email", text: $email)
                            .font(.brandBody)
                            .foregroundColor(Color("PrimaryNuriBlack"))
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .focused($isEmailFocused)
                        
                        Spacer()
                        
                        if isValidEmail {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color("PrimaryNuriLilac"))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Fixed bottom button
                Button(action: {
                    continueToNameInput()
                }) {
                    HStack {
                        Spacer()
                        Text("Confirm")
                            .font(.custom("Inter", size: 16).weight(.semibold))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(isValidEmail ? Color("PrimaryNuriLilac") : Color("PrimaryNuriLilac").opacity(0.3))
                    .cornerRadius(30)
                }
                .disabled(!isValidEmail)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemGray6))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showNameInput) {
            NameInputView()
        }
        .onAppear {
            // Load passkey email on appear
            email = UserDefaults.standard.string(forKey: "passkeyUserEmail") ?? ""
        }
    }
    
    private func continueToNameInput() {
        // Save email to StrigaSession for later use
        StrigaSession.shared.email = email
        print("[EmailConfirmation] Storing email: \(email)")
        showNameInput = true
    }
}

#Preview {
    EmailConfirmationView()
}