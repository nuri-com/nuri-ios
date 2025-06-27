import SwiftUI

/// Visual content for Nuri primary & secondary buttons (icon + label).
/// Wrap inside `Button {}` or `NavigationLink {}` where needed.
public struct NuriButton: View {
    public enum Style {
        case primary      // filled with brand lilac
        case secondary    // transparent background with stroke

        var background: Color? {
            switch self {
            case .primary:   return Color("PrimaryNuriLilac")
            case .secondary: return nil
            }
        }

        var stroke: Color? {
            switch self {
            case .primary:   return nil
            case .secondary: return Color("PrimaryNuriBlack")
            }
        }
    }

    private let icon: String
    private let title: String
    private let style: Style

    // Fixed metrics (matches current Figma)
    private let height: CGFloat = 54
    private let cornerRadius: CGFloat = 100

    public init(icon: String, title: String, style: Style = .primary) {
        self.icon = icon
        self.title = title
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color("PrimaryNuriBlack"))
                .frame(width: 24, height: 24)
            Text(title)
                .font(.brandBody)
                .foregroundColor(Color("PrimaryNuriBlack"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(style.background ?? Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(style.stroke ?? Color.clear, lineWidth: style.stroke == nil ? 0 : 1)
        )
        .cornerRadius(cornerRadius)
    }
} 