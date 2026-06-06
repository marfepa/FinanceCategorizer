import SwiftUI
import SwiftData

@main
struct FinanceCategorizerMacApp: App {
    @State private var container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            MacAppRootView()
                .environment(\.appContainer, container)
                .modelContainer(container.modelContainer)
        }
        .defaultSize(width: 1380, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
