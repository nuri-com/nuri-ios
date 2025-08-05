import SwiftUI

enum InputMode {
    case phone
    case email
    case smsCode
    
    var title: String {
        switch self {
        case .phone: return "Mobile Number"
        case .email: return "Email Address"
        case .smsCode: return "Verification Code"
        }
    }
    
    var placeholder: String {
        switch self {
        case .phone: return "0"
        case .email: return "email@example.com"
        case .smsCode: return "000000"
        }
    }
    
    var keyboardType: UIKeyboardType {
        switch self {
        case .phone: return .phonePad
        case .email: return .emailAddress
        case .smsCode: return .numberPad
        }
    }
    
    var contentType: UITextContentType? {
        switch self {
        case .phone: return .telephoneNumber
        case .email: return .emailAddress
        case .smsCode: return .oneTimeCode
        }
    }
}

struct UnifiedInputView: View {
    let mode: InputMode
    @Binding var inputText: String
    @Binding var countryCode: String
    @Binding var showCountryPicker: Bool
    let countryName: String
    let isValid: Bool
    let onNext: () -> Void
    let onCountryPicked: (SearchCountryDialCodeResult) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Add padding from top edge
            NuriHeader<AnyView, AnyView>(title: mode.title) {
                AnyView(
                    Button(action: { dismiss() }) {
                        Image("arrow-back")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(width: 32, height: 32)
                    }
                )
            } trailing: {
                AnyView(
                    Button(action: onNext) {
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
            }
            .padding(.top, 10) // Add padding from the top edge
            
            contentView()
        }
        .navigationBarHidden(true)
        .background(Color(UIColor.systemGray6))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    @ViewBuilder
    private func contentView() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Left-aligned headline
            Text(getHeadlineText())
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
            
            // Subtitle if needed
            if let subtitle = getSubtitleText() {
                Text(subtitle)
                    .font(.brandBody)
                    .foregroundColor(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, -16)
            }
            
            // Input field section
            if mode == .phone {
                // Connected country and phone fields
                VStack(spacing: 0) {
                    // Country selector
                    Button(action: { showCountryPicker = true }) {
                        HStack {
                            Text(countryName.isEmpty ? "Select country" : countryName)
                                .font(.brandBody)
                                .foregroundColor(Color("PrimaryNuriLilac"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color.white)
                    }
                    
                    Divider()
                        .background(Color(UIColor.systemGray4))
                    
                    // Phone number field
                    HStack(spacing: 4) {
                        Button(action: { showCountryPicker = true }) {
                            Text(countryCode)
                                .font(.brandBody)
                                .foregroundColor(Color("PrimaryNuriBlack"))
                        }
                        
                        Divider()
                            .frame(width: 1, height: 20)
                            .background(Color(UIColor.systemGray4))
                            .padding(.horizontal, 8)
                        
                        TextField("Your phone number", text: $inputText)
                            .focused($isInputFocused)
                            .font(.brandBody)
                            .keyboardType(mode.keyboardType)
                            .textContentType(mode.contentType)
                            .tint(Color("PrimaryNuriLilac"))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
            } else {
                // Email and SMS code fields
                VStack(alignment: .leading, spacing: 4) {
                    Text(getInputLabel())
                        .font(.custom("Inter", size: 14).weight(.medium))
                        .foregroundColor(Color("PrimaryNuriLilac"))
                    
                    TextField(mode.placeholder, text: $inputText)
                        .focused($isInputFocused)
                        .font(.brandBody)
                        .keyboardType(mode.keyboardType)
                        .textContentType(mode.contentType)
                        .tint(Color("PrimaryNuriLilac"))
                        .autocapitalization(mode == .email ? .none : .sentences)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Fixed bottom button (like WhatsApp)
            Button(action: onNext) {
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
        .background(Color(UIColor.systemGray6))
        .sheet(isPresented: $showCountryPicker) {
            SearchCountryDialCodeView() { result in
                onCountryPicked(result)
            }
        }
    }
    
    private func getHeadlineText() -> String {
        switch mode {
        case .phone:
            return "Enter your phone number"
        case .email:
            return "What's your email?"
        case .smsCode:
            return "Enter verification code"
        }
    }
    
    private func getSubtitleText() -> String? {
        switch mode {
        case .phone:
            return "Nuri will need to verify your account."
        case .email:
            return "We'll send you a verification code"
        case .smsCode:
            return "Enter the 6-digit code we sent you"
        }
    }
    
    private func getInputLabel() -> String {
        switch mode {
        case .phone:
            return "Phone number"
        case .email:
            return "Email address"
        case .smsCode:
            return "Verification code"
        }
    }
}