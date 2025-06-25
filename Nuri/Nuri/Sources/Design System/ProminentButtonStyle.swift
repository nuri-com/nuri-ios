import SwiftUI

struct ProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background((isEnabled ? NuriAsset.primaryNuriLilac : NuriAsset.disabledButtonBackground).swiftUIColor)
            .foregroundStyle(isEnabled ? Color.primary.opacity(configuration.isPressed ? 0.25 : 1) : Color.secondary)
            .font(.brandBody)
            .clipShape(Capsule())
    }
}
