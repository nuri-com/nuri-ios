import SwiftUI

struct CreateCardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigation: CreateCardNavigation

    var body: some View {
        NavigationStack {
            EmailConfirmationView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CardCreatedSuccessfully"))) { _ in
            print("[CreateCardView] Received card created notification, dismissing")
            dismiss()
            navigation.isPresented = false
        }
    }
}
