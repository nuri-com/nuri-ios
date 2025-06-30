import SwiftUI

/// 01 - 03 Residence / Citizenship / US Tax
struct ResidenceCitizenshipUSTaxView: View {
    @Environment(\.dismiss) private var dismiss

    // Struct to hold data for the success screen, making it identifiable
    struct SuccessInfo: Identifiable {
        let id = UUID()
        let userName: String?
    }

    // Selected values
    @State private var selectedCountry: Country? = Country.default
    @State private var selectedCitizenship: Country? = Country.default

    // Sheet controls & Sumsub
    @State private var showCountryPicker = false
    @State private var showCitizenshipPicker = false
    @State private var showSDK = false
    @State private var accessToken: String?
    @State private var verificationResult: Bool?
    @State private var successInfo: SuccessInfo? // Replaces showSuccess and userName

    private func startVerification() {
        SumsubService.shared.fetchAccessToken { token in
            accessToken = token
            showSDK = token != nil
        }
    }

    var body: some View {
        Screen(header: {
            NuriHeader<AnyView, EmptyView>(title: "", leading: {
                AnyView(Button(action: { dismiss() }) {
                    Image("arrow-back")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                })
            }, trailing: { EmptyView() })
        }, content: {
            VStack(spacing: 24) {
                Text("Where do you live?")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                CountryFieldView(label: "Country of Residence",
                                 value: selectedCountry?.display,
                                 action: { showCountryPicker = true })
                    .padding(.horizontal, 24)

                CountryFieldView(label: "Your citizenship",
                                 value: selectedCitizenship?.display,
                                 action: { showCitizenshipPicker = true })
                    .padding(.horizontal, 24)

                Spacer()

                // Button to trigger verification
                Button(action: { startVerification() }) {
                    NuriButton(icon: "head", title: "Start verification", style: .primary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        })
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selected: $selectedCountry)
        }
        .sheet(isPresented: $showCitizenshipPicker) {
            CountryPickerSheet(selected: $selectedCitizenship)
        }
        .fullScreenCover(isPresented: $showSDK) {
            if let token = accessToken {
                SumsubView(accessToken: token) { approved in
                    // The SDK overlay will dismiss itself; we dismiss our cover afterwards
                    showSDK = false
                    if approved {
                        SumsubService.shared.fetchApplicantName { name in
                            self.successInfo = SuccessInfo(userName: name)
                        }
                    }
                }
                .ignoresSafeArea()
            } else {
                ProgressView()
                    .onAppear {
                        startVerification()
                    }
                    .ignoresSafeArea()
            }
        }
        // Use .fullScreenCover(item:) for robust presentation
        .fullScreenCover(item: $successInfo) { info in
            let title = info.userName != nil ? "Welcome, \(info.userName!)" : "Verification successful!"
            let subtitle = "Your identity has been verified."

            SuccessView(illustration: "hand-plant", title: title, subtitle: subtitle) {
                successInfo = nil
                dismiss()
            }
        }
    }
}

// MARK: - Country model with flag
struct Country: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let name: String
    var flag: String {
        code.unicodeScalars.reduce(into: "") { result, scalar in
            if let scalar = UnicodeScalar(127397 + scalar.value) {
                result.unicodeScalars.append(scalar)
            }
        }
    }
    var display: String { "\(flag) \(name)" }

    static var `default`: Country? {
        if let code = Locale.current.regionCode,
           let name = Locale.current.localizedString(forRegionCode: code) {
            return Country(code: code, name: name)
        }
        return nil
    }

    static func ==(lhs: Country, rhs: Country) -> Bool { lhs.code == rhs.code }
}

// MARK: - Picker sheet
struct CountryPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selected: Country?
    @State private var searchText: String

    init(selected: Binding<Country?>) {
        self._selected = selected
        _searchText = State(initialValue: "")
    }

    private var allCountries: [Country] = {
        Locale.isoRegionCodes.compactMap { code in
            guard let name = Locale.current.localizedString(forRegionCode: code) else { return nil }
            return Country(code: code, name: name)
        }.sorted { $0.name < $1.name }
    }()

    private var filtered: [Country] {
        if searchText.isEmpty { return allCountries }
        return allCountries.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                HStack {
                    Text(country.flag)
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

// MARK: - Field view
private struct CountryFieldView: View {
    let label: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriLilac"))
                HStack {
                    Text(value ?? "Select")
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
            .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}