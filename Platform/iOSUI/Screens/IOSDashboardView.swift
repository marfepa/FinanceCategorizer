import SwiftUI

struct IOSDashboardView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    
    var body: some View {
        ScrollView(.vertical) {
            EmptyStateView(
                title: LocalizedStringKey("Dashboard Ready"),
                message: LocalizedStringKey("Start here with monthly balance, categories and pending review items."),
                systemImage: "chart.pie"
            )
        }
        .navigationTitle(LocalizedStringKey("Dashboard"))
    }
}
