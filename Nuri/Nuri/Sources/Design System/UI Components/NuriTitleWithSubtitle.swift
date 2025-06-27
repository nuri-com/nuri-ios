import SwiftUI

/// Simple title + subtitle block used across Nuri screens.
/// Keeps typography & spacing consistent.
public struct NuriTitleWithSubtitle: View {
    public let title: String
    public let subtitle: String
    private let verticalSpacing: CGFloat = 4

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: verticalSpacing) {
            Text(title)
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.brandCaption)
                .foregroundColor(Color("TextSecondary"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#if DEBUG
#Preview {
    NuriTitleWithSubtitle(title: "Nuri Card for Apple Pay", subtitle: "3 satoshis / byte")
        .padding()
        .previewLayout(.sizeThatFits)
}
#endif 