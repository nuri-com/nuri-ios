import SwiftUI

/// Toast-style banner that briefly appears to confirm actions (e.g. copied to clipboard).
/// Matches Figma snackbar: left icon, 2-line text, green background, rounded corners.
public struct NuriSnackbar: View {
    public enum Style {
        case success
        case error
        case info

        var background: Color {
            switch self {
            case .success: return Color("SuccessGreen") // asset color set #1CC18C
            case .error:   return Color.red
            case .info:    return Color("PrimaryNuriLilac")
            }
        }

        var iconName: String {
            switch self {
            case .success: return "checkmark"
            case .error:   return "xmark"
            case .info:    return "info"
            }
        }
    }

    private let style: Style
    private let title: String
    private let description: String

    public init(style: Style = .success, title: String, description: String) {
        self.style = style
        self.title = title
        self.description = description
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Inter", size: 14).weight(.semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.background)
        .cornerRadius(12)
        .padding(.horizontal, 24) // same side insets as buttons
    }
} 