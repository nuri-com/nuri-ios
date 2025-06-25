import SwiftUI

/// 01 - 03 Residence / Citizenship / US Tax
/// Figma: "Where do you live?" screen (lowered keyboard)
struct ResidenceCitizenshipUSTaxView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCountry: Country? = {
        // Default country from device locale
        if let code = Locale.current.regionCode,
           let name = Locale.current.localizedString(forRegionCode: code) {
            return Country(name: name)
        }
        return nil
    }()
    @State private var showCountryPicker = false
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

                Text("Where do you live?")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                // Custom dropdown field
                CountryFieldView(label: "Country of Residence",
                                 value: selectedCountry?.name,
                                 isActive: showCountryPicker,
                                 placeholder: "Select country") {
                    showCountryPicker = true
                }
                .padding(.horizontal, 24)
                .sheet(isPresented: $showCountryPicker) {
                    CountryPickerSheet(selected: $selectedCountry)
                }

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

/// Simple Country model
private struct Country: Identifiable, Equatable {
    let id = UUID()
    let name: String
}

// MARK: - Picker sheet

private struct CountryPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selected: Country?
    @State private var searchText = ""

    private var allCountries: [Country] {
        Locale.isoRegionCodes.compactMap { code in
            guard let name = Locale.current.localizedString(forRegionCode: code) else { return nil }
            return Country(name: name)
        }.sorted { $0.name < $1.name }
    }

    private var filtered: [Country] {
        if searchText.isEmpty { return allCountries }
        return allCountries.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                HStack {
                    Text(country.name)
                    Spacer()
                    if country == selected {
                        Image(systemName: "checkmark")
                            .foregroundColor(Color("PrimaryNuriLilac"))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selected = country
                    dismiss()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color("PrimaryNuriBlack"))
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
    }
}

// MARK: - Country Field

private struct CountryFieldView: View {
    let label: String
    let value: String?
    let isActive: Bool
    let placeholder: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.brandCaption)
                    .foregroundColor(Color("PrimaryNuriLilac"))
                HStack {
                    Text(value ?? placeholder)
                        .font(.brandBody)
                        .foregroundColor(value == nil ? Color.secondary : Color("PrimaryNuriBlack"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color("PrimaryNuriBlack"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(Color("PrimaryNuriLilac"))
                    .frame(height: 1), alignment: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
} 