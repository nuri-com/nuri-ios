import SwiftUI
import UIKit
import AuthenticationServices
import BitcoinDevKit

struct WelcomeView: View {

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false
    @State private var email = ""
    @State private var showEmailSuggestions = false
    @State private var selectedSuggestion = ""
    @FocusState private var emailFieldFocused: Bool
    
    private let emailDomains = ["gmail.com", "icloud.com", "outlook.com", "nuri.com"]
    
    private var isEmailValid: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private var filteredSuggestions: [String] {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If no @ symbol yet, don't show suggestions
        guard let atIndex = trimmedEmail.firstIndex(of: "@") else {
            return []
        }
        
        // Get the part after @
        let domainPart = String(trimmedEmail[trimmedEmail.index(after: atIndex)...])
        
        // If nothing after @, show all domains
        if domainPart.isEmpty {
            return emailDomains
        }
        
        // Filter domains that start with the typed part
        return emailDomains.filter { $0.lowercased().hasPrefix(domainPart.lowercased()) }
    }
    
    private var suggestedEmail: String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only suggest if we have @ but the domain isn't complete
        guard let atIndex = trimmedEmail.firstIndex(of: "@"),
              !filteredSuggestions.isEmpty else {
            return nil
        }
        
        let localPart = String(trimmedEmail[..<atIndex])
        return localPart + "@" + filteredSuggestions[0]
    }

    var body: some View {
        Screen {
            // Standard Nuri header like Card screen
            NuriHeader<AnyView, AnyView>(title: "") {
                AnyView(
                    Image("HeaderLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                )
            } trailing: {
                AnyView(
                    Button(action: {
                        Task {
                            await authenticateWithPasskey()
                        }
                    }) {
                        Text("Recover Wallet")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                    .disabled(isAuthenticating || !isEmailValid || email.isEmpty)
                    .opacity(isEmailValid && !email.isEmpty ? 1.0 : 0.5)
                )
            }
        } content: {
            VStack(spacing: 24) {
                // Title section
                VStack(spacing: 8) {
                    Text("Your Biometrics. Your Bitcoin. Your Money.")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter your email")
                        .font(.caption)
                        .foregroundColor(Color("PrimaryNuriBlack").opacity(0.6))
                    
                    ZStack(alignment: .leading) {
                        // Use app's standard background color
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(emailFieldFocused ? Color("PrimaryNuriBlack") : Color("PrimaryNuriBlack").opacity(0.2), lineWidth: 1)
                            )
                        
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundColor(Color("PrimaryNuriBlack"))
                                .frame(width: 20)
                            
                            ZStack(alignment: .leading) {
                                // Ghost text suggestion
                                if let suggestion = suggestedEmail, !suggestion.isEmpty {
                                    Text(suggestion)
                                        .foregroundColor(Color("PrimaryNuriBlack").opacity(0.3))
                                        .font(.brandBody)
                                        .allowsHitTesting(false)
                                }
                                
                                TextField("Email address", text: $email)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                                    .font(.brandBody)
                                    .focused($emailFieldFocused)
                                    .onChange(of: email) { newValue in
                                        showEmailSuggestions = !filteredSuggestions.isEmpty
                                    }
                                    .onSubmit {
                                        // If there's a suggestion and user hits enter, complete it
                                        if let suggestion = suggestedEmail {
                                            email = suggestion
                                        } else if isEmailValid && !isAuthenticating {
                                            Task {
                                                await loginOrCreateAccount()
                                            }
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                    .frame(height: 56)
                    
                    // Email domain suggestions
                    if showEmailSuggestions && emailFieldFocused && !filteredSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredSuggestions, id: \.self) { domain in
                                Button(action: {
                                    if let atIndex = email.firstIndex(of: "@") {
                                        let localPart = String(email[..<atIndex])
                                        email = localPart + "@" + domain
                                        showEmailSuggestions = false
                                        emailFieldFocused = false
                                    }
                                }) {
                                    HStack {
                                        if let atIndex = email.firstIndex(of: "@") {
                                            let localPart = String(email[..<atIndex])
                                            Text("\(localPart)@\(domain)")
                                                .foregroundColor(Color("PrimaryNuriBlack"))
                                                .font(.brandBody)
                                        } else {
                                            Text(domain)
                                                .foregroundColor(Color("PrimaryNuriBlack"))
                                                .font(.brandBody)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(uiColor: .systemGray6))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if domain != filteredSuggestions.last {
                                    Divider()
                                        .background(Color("PrimaryNuriBlack").opacity(0.1))
                                }
                            }
                        }
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("PrimaryNuriBlack").opacity(0.2), lineWidth: 1)
                        )
                        .shadow(radius: 2)
                    }
                    
                    if !email.isEmpty && !isEmailValid {
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                // Login button using NuriButton component
                Button(action: {
                    Task {
                        await loginOrCreateAccount()
                    }
                }) {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("PrimaryNuriBlack")))
                            .frame(height: 54)
                    } else {
                        NuriButton(
                            icon: "passkey",
                            title: "Login",
                            style: .primary
                        )
                    }
                }
                .disabled(isAuthenticating || !isEmailValid || email.isEmpty)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .onAppear {
            // Auto-focus the email field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                emailFieldFocused = true
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
    private func loginOrCreateAccount() async {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                throw PasskeyError.invalidURL
            }
            
            // First try to authenticate with existing passkey
            do {
                let result = try await PasskeyAuthenticationService.shared.authenticateWithPasskey(
                    username: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    presentationAnchor: window
                )
                
                if result.verified {
                    // Check if the authenticated username matches the entered email
                    if let username = result.username, username == email.trimmingCharacters(in: .whitespacesAndNewlines) {
                        // Store the email
                        UserDefaults.standard.set(email.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "passkeyUserEmail")
                        
                        // Successfully authenticated with correct email
                        self.isUserLoggedIn = true
                    } else {
                        // Wrong account - the passkey doesn't match the entered email
                        throw NSError(domain: "PasskeyError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No passkey found for this email address. Please check your email or create a new account."])
                    }
                }
            } catch {
                // No existing passkey found or wrong email, create new account
                let result = try await PasskeyAuthenticationService.shared.createPasskey(
                    username: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    presentationAnchor: window
                )
                
                if result.verified {
                    // Store email in UserDefaults
                    UserDefaults.standard.set(email.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "passkeyUserEmail")
                    
                    // Successfully created and authenticated
                    self.isUserLoggedIn = true
                } else {
                    throw PasskeyError.serverError
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    @MainActor
    private func authenticateWithPasskey() async {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                throw PasskeyError.invalidURL
            }
            
            let result = try await PasskeyAuthenticationService.shared.authenticateWithPasskey(
                username: email.trimmingCharacters(in: .whitespacesAndNewlines),
                presentationAnchor: window
            )
            
            if result.verified {
                // Store the recover email if authentication was successful
                UserDefaults.standard.set(email.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "passkeyUserEmail")
                
                // Successfully authenticated
                self.isUserLoggedIn = true
            } else {
                throw PasskeyError.serverError
            }
        } catch PasskeyError.noPasskeysFound {
            errorMessage = "No wallet found for this email. Please check your email or create a new wallet."
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - View Helpers
}

#Preview {
    WelcomeView()
}