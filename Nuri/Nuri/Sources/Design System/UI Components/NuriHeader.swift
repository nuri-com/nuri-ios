import SwiftUI

/// Standard top bar used across Nuri screens.
/// Provides fixed sizing & spacing so every screen is visually consistent.
public struct NuriHeader<Leading: View, Trailing: View>: View {
    private let title: String
    private let leading: Leading
    private let trailing: Trailing

    // Design constants
    private let height: CGFloat = 44      // content box
    private let sideInset: CGFloat = 24   // horizontal padding
    private let bottomGap: CGFloat = 16   // gap to body content

    public init(
        title: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                leading
                Spacer()
                Text(title)
                    .font(.custom("Inter", size: 16).weight(.semibold))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                Spacer()
                trailing
            }
            .padding(.horizontal, sideInset)
            .frame(height: height)
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }

            Color.clear.frame(height: bottomGap)
        }
    }
}

// MARK: - Preset factories
public extension NuriHeader {
    /// Logo on the left, standard close button on the right.
    static func logo(title: String, onClose: @escaping () -> Void) -> NuriHeader<AnyView, AnyView> {
        NuriHeader<AnyView, AnyView>(title: title) {
            AnyView(
                Image("HeaderLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 32, height: 32)
            )
        } trailing: {
            AnyView(
                Button(action: onClose) {
                    Image("delete-close")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                }
            )
        }
    }

    /// Back arrow on the left, close button on the right.
    static func backAndClose(title: String, onBack: @escaping () -> Void, onClose: @escaping () -> Void) -> NuriHeader<AnyView, AnyView> {
        NuriHeader<AnyView, AnyView>(title: title) {
            AnyView(
                Button(action: onBack) {
                    Image("arrow-back")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                }
            )
        } trailing: {
            AnyView(
                Button(action: onClose) {
                    Image("delete-close")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                }
            )
        }
    }

    /// Logo on left, small CTA button on right.
    static func logoAndCTA(title: String, cta: String, onCTA: @escaping () -> Void) -> NuriHeader<AnyView, AnyView> {
        NuriHeader<AnyView, AnyView>(title: title) {
            AnyView(
                Image("HeaderLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 32, height: 32)
            )
        } trailing: {
            AnyView(
                Button(action: onCTA) {
                    Text(cta)
                        .font(.custom("Inter", size: 14).weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("PrimaryNuriBlack"))
                        .cornerRadius(64)
                }
            )
        }
    }
} 