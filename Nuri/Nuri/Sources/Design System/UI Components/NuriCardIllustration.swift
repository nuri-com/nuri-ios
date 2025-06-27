import SwiftUI

/// Reusable illustration of the Nuri card, scaled to full available width and
/// horizontally padded to align with standard button margins (24 pt on each side).
public struct NuriCardIllustration: View {
    public init() {}

    public var body: some View {
        Image("card-flattend")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24) // matches button horizontal padding
    }
} 