import SwiftUI

/// Standard menu row used in settings & similar screens.
/// Icon – Title – Subtitle – optional trailing control.
public struct NuriMenuRow<Trailing: View>: View {
    private let icon: String
    private let title: String
    private let subtitle: String
    private let subtitleColor: Color
    private let trailing: Trailing

    // Layout constants
    private let horizontalInset: CGFloat = 24
    private let verticalInset: CGFloat = 12
    private let horizontalSpacing: CGFloat = 16
    private let iconSize: CGFloat = 32

    public init(
        icon: String,
        title: String,
        subtitle: String,
        subtitleColor: Color = Color("TextSecondary"),
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: horizontalSpacing) {
            Image(icon)
                .resizable()
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Inter", size: 16).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                Text(subtitle)
                    .font(.custom("Inter", size: 16))
                    .foregroundColor(subtitleColor)
            }

            Spacer()

            trailing
        }
        .padding(.vertical, verticalInset)
        .padding(.horizontal, horizontalInset)
    }
}

// Convenience initialiser when there is no trailing view
public extension NuriMenuRow where Trailing == EmptyView {
    init(
        icon: String,
        title: String,
        subtitle: String,
        subtitleColor: Color = Color("TextSecondary")
    ) {
        self.init(icon: icon, title: title, subtitle: subtitle, subtitleColor: subtitleColor) {
            EmptyView()
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        NuriMenuRow(icon: "lock", title: "Security", subtitle: "Account is secured with authentication") {
            Image(systemName: "chevron.right")
        }
        NuriMenuRow(icon: "icloud-download", title: "iCloud Backup", subtitle: "We automatically saved a recovery key to iCloud") {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
        NuriMenuRow(icon: "touch-id", title: "Add Hardware Key", subtitle: "Add a security key to your account")
    }
    .previewLayout(.sizeThatFits)
}
#endif