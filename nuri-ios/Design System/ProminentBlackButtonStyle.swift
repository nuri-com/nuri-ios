import SwiftUI

struct ProminentBlackButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(isEnabled ? Color.textPrimary : Color.disabledButtonBackground)
            .foregroundStyle(isEnabled ? Color.white.opacity(configuration.isPressed ? 0.25 : 1): Color.secondary)
            .font(.brandBody)
            .clipShape(Capsule())
    }
}
