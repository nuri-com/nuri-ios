import SwiftUI
import Combine
import UIKit

class CreateCardNavigation: ObservableObject {
     @Published var isPresented: Bool = false
}

class CardViewModel: ObservableObject {

    private let userSettings = ObservableUserSettings()
    private var tokens: Set<AnyCancellable> = []

    @Published var hasCard: Bool = false

    init() {
        userSettings.strigaUserId
            .sink { [weak self] userId in
                self?.updateHasCard()
            }
            .store(in: &tokens)
    }

    private func updateHasCard() {
        Task { @MainActor in
            hasCard = UserSettings().strigaUserId != nil
        }
    }
}

struct CardView: View {

    @ObservedObject var viewModel = CardViewModel()

    @StateObject private var navigation = CreateCardNavigation()

    var body: some View {
        Group {
            if viewModel.hasCard {
                CardViewActive()
            } else {
                NoCardView()
            }
        }
        .sheet(isPresented: $navigation.isPresented) {
            CreateCardView()
        }
        .environmentObject(navigation)
    }
}

#if DEBUG
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView()
    }
}
#endif
