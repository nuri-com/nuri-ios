import SwiftUI

struct LoadingOverlay: View {
    let title: String
    let subtitle: String?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(32)
            .background(Color("PrimaryNuriBlack"))
            .cornerRadius(16)
        }
    }
}

extension View {
    func loadingOverlay(isPresented: Bool, title: String, subtitle: String? = nil) -> some View {
        self.overlay(
            Group {
                if isPresented {
                    LoadingOverlay(title: title, subtitle: subtitle)
                }
            }
        )
    }
}