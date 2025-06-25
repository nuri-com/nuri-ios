import SwiftUI

/// Progress bar height constant
private let progressBarHeight: CGFloat = 4

/// 01 - 03 Residence / Citizenship / US Tax
/// Figma: "Where do you live?" screen (lowered keyboard)
struct ResidenceCitizenshipUSTaxView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var country: String = ""
    @FocusState private var isFocused: Bool

    private let currentStep: Int = 1
    private let totalSteps: Int = 3

    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            VStack(spacing: 24) {
                // Top navigation with back arrow
                HStack {
                    Button(action: { dismiss() }) {
                        Image("vector-back-arrow")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 44)

                // Progress bar
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(.linear)
                    .tint(Color("PrimaryNuriBlack"))
                    .frame(height: progressBarHeight)
                    .padding(.horizontal, 24)

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