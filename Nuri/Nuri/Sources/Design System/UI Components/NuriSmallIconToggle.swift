import SwiftUI

/// Small square icon with a caption that toggles between two states (active / inactive).
/// Useful for card detail toggle, eye show/hide, etc.
public struct NuriSmallIconToggle: View {
    @Binding private var isActive: Bool
    private let label: String
    private let iconActive: String
    private let iconInactive: String
    private let action: (() -> Void)?

    // Design constants
    private let iconSize: CGFloat = 32
    private let verticalSpacing: CGFloat = 4

    public init(isActive: Binding<Bool>,
                label: String,
                iconActive: String,
                iconInactive: String,
                action: (() -> Void)? = nil) {
        self._isActive = isActive
        self.label = label
        self.iconActive = iconActive
        self.iconInactive = iconInactive
        self.action = action
    }

    public var body: some View {
        Button(action: {
            isActive.toggle()
            action?()
        }) {
            VStack(spacing: verticalSpacing) {
                Image(isActive ? iconActive : iconInactive)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: iconSize, height: iconSize)
                Text(label)
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriBlack"))
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 32) {
        NuriSmallIconToggle(isActive: .constant(false),
                            label: "Details",
                            iconActive: "eye",
                            iconInactive: "eye_hidden")
        NuriSmallIconToggle(isActive: .constant(true),
                            label: "Details",
                            iconActive: "eye",
                            iconInactive: "eye_hidden")
    }
}
#endif 