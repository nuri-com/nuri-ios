import SwiftUI

struct NameInputView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var showDateOfBirthView = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case firstName
        case lastName
    }
    
    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            NuriHeader<AnyView, AnyView>(title: "", leading: {
                AnyView(
                    Image("HeaderLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                )
            }, trailing: {
                AnyView(
                    Button(action: {
                        saveNameAndContinue()
                    }) {
                        Text("Next")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1.0 : 0.5)
                )
            })
            .padding(.top, 10) // Add padding from the top edge
            
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Headline
                Text("Your name")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                // Subtitle
                Text("Please enter your legal name as it appears on your ID")
                    .font(.brandBody)
                    .foregroundColor(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, -16)
                
                // Input fields
                VStack(spacing: 16) {
                    // First name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First name")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriLilac"))
                        
                        TextField("John", text: $firstName)
                            .focused($focusedField, equals: .firstName)
                            .font(.brandBody)
                            .textContentType(.givenName)
                            .tint(Color("PrimaryNuriLilac"))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    
                    // Last name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last name")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriLilac"))
                        
                        TextField("Doe", text: $lastName)
                            .focused($focusedField, equals: .lastName)
                            .font(.brandBody)
                            .textContentType(.familyName)
                            .tint(Color("PrimaryNuriLilac"))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Fixed bottom button
                Button(action: {
                    saveNameAndContinue()
                }) {
                    HStack {
                        Spacer()
                        Text("Next")
                            .font(.custom("Inter", size: 16).weight(.semibold))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(isValid ? Color("PrimaryNuriLilac") : Color("PrimaryNuriLilac").opacity(0.3))
                    .cornerRadius(30)
                }
                .disabled(!isValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onDisappear {
            // Persist any partially entered name so it isn't lost if user navigates away
            let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedFirstName.isEmpty {
                StrigaSession.shared.firstName = trimmedFirstName
            }
            if !trimmedLastName.isEmpty {
                StrigaSession.shared.lastName = trimmedLastName
            }
        }
        .background(Color(UIColor.systemGray6))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showDateOfBirthView) {
            DateOfBirthView()
        }
        .onAppear {
            // Focus first field shortly after appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .firstName
            }
        }
    }
    
    private func saveNameAndContinue() {
        // Save the name to StrigaSession
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        StrigaSession.shared.firstName = trimmedFirstName
        StrigaSession.shared.lastName = trimmedLastName
        StrigaSession.shared.name = "\(trimmedFirstName) \(trimmedLastName)" // For backward compatibility
        
        print("[NameInput] Storing name:")
        print("  - First Name: \(trimmedFirstName)")
        print("  - Last Name: \(trimmedLastName)")
        
        showDateOfBirthView = true
    }
}

#Preview {
    NameInputView()
}