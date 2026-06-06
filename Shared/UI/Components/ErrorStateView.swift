import SwiftUI

struct ErrorStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        EmptyStateView(title: title, message: message, systemImage: "exclamationmark.triangle")
    }
}
