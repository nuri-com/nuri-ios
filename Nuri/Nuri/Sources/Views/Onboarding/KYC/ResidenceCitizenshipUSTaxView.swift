import SwiftUI

/// 01 - 03 Residence / Citizenship / US Tax
/// Figma: "Where do you live?" screen (lowered keyboard)
struct ResidenceCitizenshipUSTaxView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var country: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            VStack(spacing: 24) {
                // Top bar with arrow and symmetric layout
                HStack {
                    Button(action: { dismiss() }) {
                        Image("arrow-back")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    Spacer()
                    // Right placeholder to balance layout
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 44)

                Spacer().frame(height: 44)
                Text("Where do you live?")
                    .font(.brandTitle1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .padding(.horizontal, 24)

                // Country text field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Country of Residence")
                        .font(.brandBody)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                    TextField("Search or type country", text: $country)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.alphabet)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: {
                    // TODO: handle next step in KYC flow
                }) {
                    Text("Next")
                        .font(.brandBody)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color("PrimaryNuriLilac"))
                        .cornerRadius(100)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ResidenceCitizenshipUSTaxView()
    }
}
#endif 