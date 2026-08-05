import SwiftUI

struct IOSPlanningView: View {
    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Image(systemName: "target")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppColors.accent)
            Text(LocalizedStringKey("Planning"))
                .font(AppTypography.sectionTitle)
            Text(LocalizedStringKey("Manage budgets and savings goals directly on macOS or track metrics here."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(LocalizedStringKey("Planning"))
    }
}
