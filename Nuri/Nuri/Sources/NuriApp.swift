import SwiftUI

@main
struct NuriApp: App {

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    var body: some Scene {
        WindowGroup {
            if isUserLoggedIn {
                EmptyView()
            } else {
                EmptyView()
            }
        }
    }
}
