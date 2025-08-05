import SwiftUI

struct DateOfBirthView: View {
    @State private var selectedDate = Date()
    @State private var showAddressView = false
    @FocusState private var isDatePickerFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    // Calculate date range: 18-100 years old
    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let minDate = calendar.date(byAdding: .year, value: -100, to: now) ?? now
        let maxDate = calendar.date(byAdding: .year, value: -18, to: now) ?? now
        return minDate...maxDate
    }
    
    // Default to 25 years ago
    private var defaultDate: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
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
                        saveDateAndContinue()
                    }) {
                        Text("Next")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                )
            })
            .padding(.top, 10)
            
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Headline
                Text("Your date of birth")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                // Subtitle
                Text("We need this information to verify your identity")
                    .font(.brandBody)
                    .foregroundColor(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, -16)
                
                // Date picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date of birth")
                        .font(.custom("Inter", size: 14).weight(.medium))
                        .foregroundColor(Color("PrimaryNuriLilac"))
                    
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: dateRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .focused($isDatePickerFocused)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Fixed bottom button
                Button(action: {
                    saveDateAndContinue()
                }) {
                    HStack {
                        Spacer()
                        Text("Next")
                            .font(.custom("Inter", size: 16).weight(.semibold))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Color("PrimaryNuriLilac"))
                    .cornerRadius(30)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemGray6))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showAddressView) {
            AddressInputView()
        }
        .onAppear {
            // Set default date to 25 years ago
            selectedDate = defaultDate
        }
    }
    
    private func saveDateAndContinue() {
        // Save the date of birth to StrigaSession
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        if let year = components.year,
           let month = components.month,
           let day = components.day {
            // Store date in StrigaSession
            StrigaSession.shared.dateOfBirth = StrigaSession.Date(
                year: Int32(year),
                month: Int32(month),
                day: Int32(day)
            )
            
            let dateString = "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
            print("[DateOfBirth] Storing date: \(dateString)")
            print("  - Year: \(year)")
            print("  - Month: \(month)")
            print("  - Day: \(day)")
            
            // Navigate to address input
            showAddressView = true
        }
    }
}

#Preview {
    DateOfBirthView()
}