import SwiftUI

struct SuccessView: View {
    let illustration: String
    let title: String
    let subtitle: String
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Screen(header: {
            AnyView(
                NuriHeader<AnyView, AnyView>.logo(title: "", onClose: {
                    onDone()
                    dismiss()
                })
            )
        }, content: {
            VStack(spacing: 0) {
                Spacer()

                Image(illustration)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(.bottom, 48)

                Text(title)
                    .font(.brandTitle1)
                    .foregroundColor(Color("TextPrimary"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)

                Text(subtitle)
                    .font(.brandBody)
                    .foregroundColor(Color("TextSecondary"))
                    .multilineTextAlignment(.center)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)

            Button(action: {
                onDone()
                dismiss()
            }) {
                NuriButton(icon: "normal-check", title: "Done", style: .primary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        })
    }
}
