import SwiftUI

struct FinancialPositionCard: View {
    let snapshot: FinancialPlanningSnapshot
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage
    let openGoals: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack(alignment: .firstTextBaseline) {
                Label(LocalizedStringKey("Accumulated position"), systemImage: "banknote.fill")
                    .font(AppTypography.sectionTitle)
                Spacer()
                Button(LocalizedStringKey("Manage savings goals"), action: openGoals)
                    .appSecondaryGlassButton()
                    .controlSize(.small)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap)
                ],
                spacing: AppLayoutMetrics.contentGap
            ) {
                positionMetric(
                    title: LocalizedStringKey("Current balance"),
                    value: renderAmount(snapshot.totalBalance),
                    tint: snapshot.isBalanceConfirmed ? AppColors.income : AppColors.warning
                )
                positionMetric(
                    title: LocalizedStringKey("Assigned to goals"),
                    value: renderAmount(snapshot.allocatedToGoals),
                    tint: AppColors.neutral
                )
                positionMetric(
                    title: LocalizedStringKey("Available to assign"),
                    value: renderAmount(snapshot.availableBalance),
                    tint: snapshot.availableBalance >= .zero ? AppColors.income : AppColors.expense
                )
                positionMetric(
                    title: LocalizedStringKey("Projected balance 12M"),
                    value: renderAmount(snapshot.projectedBalance12Months),
                    tint: snapshot.projectedBalance12Months >= snapshot.totalBalance ? AppColors.income : AppColors.warning
                )
            }

            HStack(spacing: 6) {
                Image(systemName: snapshot.isBalanceConfirmed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                Text(snapshot.isBalanceConfirmed
                     ? LocalizedStringKey("Balance confirmed from a bank balance or manual snapshot.")
                     : LocalizedStringKey("Balance is estimated from imported movements. Confirm it in Savings Goals for realistic projections."))
            }
            .font(.caption)
            .foregroundStyle(snapshot.isBalanceConfirmed ? AppColors.income : AppColors.warning)

            if snapshot.historyMonths > 0 {
                Text(appLanguage.localized(
                    "planning.savingsAverage",
                    renderAmount(snapshot.monthlySavingsAverage),
                    appLanguage.formatInteger(snapshot.historyMonths)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.card)
    }

    private func positionMetric(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayoutMetrics.contentGap)
        .padding(.vertical, 12)
        .liquidGlassPill(padding: 0, tint: tint)
    }
}
