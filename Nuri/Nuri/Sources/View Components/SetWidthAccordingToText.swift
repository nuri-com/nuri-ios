import SwiftUI

struct SetWidthAccordingToText: ViewModifier {
    let text: String

    @State private var textWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(width: textWidth)
            .background {
                Text(text)
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        self.textWidth = width
                    }
            }
    }
}

extension View {
    func setWidthAccordingTo(text: String) -> some View {
        modifier(SetWidthAccordingToText(text: text))
    }
}
