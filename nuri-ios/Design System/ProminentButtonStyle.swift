import SwiftUI

struct ProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(isEnabled ? Color.accentColor : Color.disabledButtonBackground)
            .foregroundStyle(isEnabled ? Color.primary: Color.secondary)
            .font(.brandBody)
            .clipShape(Capsule())
    }
}
