import SwiftUI
import MapKit

struct AddressInputView: View {
    @State private var searchText = ""
    @State private var streetAddress = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var showingSuggestions = false
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var showPhoneNumberView = false
    
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    private var isValid: Bool {
        !streetAddress.isEmpty && !city.isEmpty && !postalCode.isEmpty && !country.isEmpty
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
                        saveAddressAndContinue()
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Headline
                    Text("Your address")
                        .font(.brandTitle1)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    // Subtitle
                    Text("Please enter your residential address")
                        .font(.brandBody)
                        .foregroundColor(Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, -16)
                    
                    // Search field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search address")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriLilac"))
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.secondary)
                            
                            TextField("Start typing your address...", text: $searchText)
                                .focused($isSearchFocused)
                                .font(.brandBody)
                                .tint(Color("PrimaryNuriLilac"))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                                .onChange(of: searchText) { _, newValue in
                                    searchCompleter.searchQuery = newValue
                                    showingSuggestions = !newValue.isEmpty
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .padding(.horizontal, 24)
                    
                    // Suggestions
                    if showingSuggestions && !searchCompleter.results.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchCompleter.results.prefix(5), id: \.self) { completion in
                                Button(action: {
                                    selectAddress(completion)
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(completion.title)
                                            .font(.brandBody)
                                            .foregroundColor(Color("PrimaryNuriBlack"))
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.custom("Inter", size: 14))
                                                .foregroundColor(Color.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                
                                if completion != searchCompleter.results.prefix(5).last {
                                    Divider()
                                        .background(Color(UIColor.systemGray4))
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 24)
                    }
                    
                    // Address fields
                    VStack(spacing: 16) {
                        // Street address
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Street address")
                                .font(.custom("Inter", size: 14).weight(.medium))
                                .foregroundColor(Color("PrimaryNuriLilac"))
                            
                            TextField("123 Main Street", text: $streetAddress)
                                .font(.brandBody)
                                .tint(Color("PrimaryNuriLilac"))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        
                        // City
                        VStack(alignment: .leading, spacing: 4) {
                            Text("City")
                                .font(.custom("Inter", size: 14).weight(.medium))
                                .foregroundColor(Color("PrimaryNuriLilac"))
                            
                            TextField("Berlin", text: $city)
                                .font(.brandBody)
                                .tint(Color("PrimaryNuriLilac"))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        
                        // Postal code
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Postal code")
                                .font(.custom("Inter", size: 14).weight(.medium))
                                .foregroundColor(Color("PrimaryNuriLilac"))
                            
                            TextField("10115", text: $postalCode)
                                .font(.brandBody)
                                .tint(Color("PrimaryNuriLilac"))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .overlay(Rectangle().fill(Color("PrimaryNuriLilac")).frame(height: 1), alignment: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        
                        // Country
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Country")
                                .font(.custom("Inter", size: 14).weight(.medium))
                                .foregroundColor(Color("PrimaryNuriLilac"))
                            
                            TextField("Germany", text: $country)
                                .font(.brandBody)
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
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Fixed bottom button
            Button(action: {
                saveAddressAndContinue()
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
            .background(Color(UIColor.systemGray6))
        }
        .background(Color(UIColor.systemGray6))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showPhoneNumberView) {
            PhoneNumberView()
        }
        .onTapGesture {
            showingSuggestions = false
            isSearchFocused = false
        }
        .onAppear {
            // Auto-focus the search field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFocused = true
            }
        }
    }
    
    private func selectAddress(_ completion: MKLocalSearchCompletion) {
        showingSuggestions = false
        isSearchFocused = false
        
        // Perform a search to get full address details
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let mapItem = response.mapItems.first else { return }
            
            let placemark = mapItem.placemark
            
            DispatchQueue.main.async {
                self.streetAddress = [placemark.subThoroughfare, placemark.thoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                self.city = placemark.locality ?? ""
                self.postalCode = placemark.postalCode ?? ""
                self.country = placemark.country ?? ""
                self.searchText = ""
            }
        }
    }
    
    private func saveAddressAndContinue() {
        // Save address to StrigaSession
        let countryCode = getCountryCode(for: country)
        StrigaSession.shared.address = StrigaSession.Address(
            addressLine1: streetAddress,
            city: city,
            country: countryCode,
            postalCode: postalCode
        )
        print("[AddressInput] Storing address:")
        print("  - Street: \(streetAddress)")
        print("  - City: \(city)")
        print("  - Country: \(country) -> Code: \(countryCode)")
        print("  - Postal Code: \(postalCode)")
        showPhoneNumberView = true
    }
    
    private func getCountryCode(for countryName: String) -> String {
        // Simple mapping - in production, use a proper country code library
        let countryMap = [
            "Germany": "DE",
            "United States": "US",
            "United Kingdom": "GB",
            "France": "FR",
            "Spain": "ES",
            "Italy": "IT",
            "Netherlands": "NL",
            "Poland": "PL"
        ]
        return countryMap[countryName] ?? "DE"
    }
}

// Location search completer for address autocomplete
class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    var searchQuery: String = "" {
        didSet {
            if searchQuery.isEmpty {
                results = []
            } else {
                completer.queryFragment = searchQuery
            }
        }
    }
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Address search error: \(error)")
    }
}

#Preview {
    AddressInputView()
}