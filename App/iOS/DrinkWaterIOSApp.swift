import SwiftUI

@main
struct DrinkWaterIOSApp: App {
    @State private var store = HydrationStore()

    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
        }
    }
}
