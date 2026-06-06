import SwiftUI
import SwiftData

@main
struct FinanceCategorizerIOSApp: App {
    @State private var container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            IOSAppRootView()
                .environment(\.appContainer, container)
                .modelContainer(container.modelContainer)
        }
    }
}
