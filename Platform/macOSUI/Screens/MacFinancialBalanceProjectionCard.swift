import Charts
import SwiftUI

struct FinancialBalanceProjectionCard: View {
    let snapshot: FinancialPlanningSnapshot
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .foregroundStyle(AppColors.income)
                        .frame(width: 38, height: 38)
                        .liquidGlassPill(padding: 0, tint: AppColors.income)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Balance forecast"))
                            .font(AppTypography.sectionTitle)
                        Text(LocalizedStringKey("How your confirmed balance could evolve with the current saving pace."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(snapshot.isBalanceConfirmed
                     ? LocalizedStringKey("Confirmed")
                     : LocalizedStringKey("Needs confirmation"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snapshot.isBalanceConfirmed ? AppColors.income : AppColors.warning)
                    .liquidGlassPill(
                        padding: 10,
                        tint: snapshot.isBalanceConfirmed ? AppColors.income : AppColors.warning
                    )
            }

            Text(appLanguage.localized(
                "planning.projectionBasis",
                renderAmount(snapshot.recurringMonthlyIncome),
                renderAmount(snapshot.recurringMonthlyExpenses),
                renderAmount(snapshot.monthlySavingsAverage),
                appLanguage.formatInteger(snapshot.historyMonths)
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if snapshot.balanceProjection.isEmpty {
                Text(LocalizedStringKey("Import movements or confirm a current bank balance to start planning."))
                    .foregroundStyle(.secondary)
            } else {
                chart

                HStack(spacing: AppLayoutMetrics.sectionGap) {
                    legendItem(title: "Total balance", tint: AppColors.income)
                    legendItem(title: "Available balance", tint: AppColors.neutral)
                    Spacer()
                    Text(LocalizedStringKey("Projected scenario"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let selectedPoint {
                    InteractiveChartReadout(
                        title: appLanguage.format(date: selectedPoint.date, dateStyle: .medium),
                        values: [
                            (appLanguage.localized("Total balance"), renderAmount(selectedPoint.balance)),
                            (appLanguage.localized("Available balance"), renderAmount(selectedPoint.availableBalance))
                        ]
                    )
                }
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
                projectionMetric(
                    title: "Current balance",
                    value: snapshot.totalBalance,
                    tint: snapshot.isBalanceConfirmed ? AppColors.income : AppColors.warning
                )
                projectionMetric(
                    title: "Recurring monthly saving",
                    value: snapshot.monthlySavingsAverage,
                    tint: snapshot.monthlySavingsAverage >= .zero ? AppColors.income : AppColors.expense
                )
                projectionMetric(
                    title: "Balance in 12 months",
                    value: snapshot.projectedBalance12Months,
                    tint: snapshot.projectedBalance12Months >= snapshot.totalBalance ? AppColors.income : AppColors.warning
                )
                projectionMetric(
                    title: "Free balance in 12 months",
                    value: snapshot.projectedAvailableBalance12Months,
                    tint: snapshot.projectedAvailableBalance12Months >= snapshot.availableBalance ? AppColors.income : AppColors.warning
                )
            }

            Text(LocalizedStringKey("Projection uses the average net saving from available history and planned goal contributions. It is a scenario, not a guaranteed bank balance."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if snapshot.historicalMonthlySavingsAverage != snapshot.monthlySavingsAverage {
                Text(appLanguage.localized(
                    "planning.historicalComparison",
                    renderAmount(snapshot.historicalMonthlySavingsAverage)
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private var selectedPoint: BalanceProjectionPoint? {
        guard let selectedDate else { return nil }
        return snapshot.balanceProjection.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var chart: some View {
        Chart {
            ForEach(snapshot.balanceProjection) { point in
                LineMark(
                    x: .value("Month", point.date),
                    y: .value("Total balance", decimalValue(point.balance)),
                    series: .value("Series", "Total balance")
                )
                .foregroundStyle(AppColors.income.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                LineMark(
                    x: .value("Month", point.date),
                    y: .value("Available balance", decimalValue(point.availableBalance)),
                    series: .value("Series", "Available balance")
                )
                .foregroundStyle(AppColors.neutral.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 4]))
            }

            if let currentPoint = snapshot.balanceProjection.first {
                RuleMark(x: .value("Current", currentPoint.date))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Current", currentPoint.date),
                    y: .value("Current balance", decimalValue(currentPoint.balance))
                )
                .foregroundStyle(AppColors.income)
                .symbolSize(90)
            }
            if let selectedDate {
                RuleMark(x: .value("Month", selectedDate))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
        }
        .frame(height: 280)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateProjectionDateSelection(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { value in
                                updateProjectionDateSelection(at: value.location, proxy: proxy, geometry: geometry)
                            }
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            if let selectedPoint {
                InChartCalloutOverlay(
                    title: appLanguage.format(date: selectedPoint.date, dateStyle: .medium),
                    items: [
                        InChartCalloutOverlayItem(label: appLanguage.localized("Total balance"), value: renderAmount(selectedPoint.balance), color: AppColors.income),
                        InChartCalloutOverlayItem(label: appLanguage.localized("Available balance"), value: renderAmount(selectedPoint.availableBalance), color: AppColors.neutral)
                    ],
                    alignment: .topLeading
                )
            }
        }
    }

    private func updateProjectionDateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let xPosition = location.x - plotFrame.origin.x
        guard xPosition >= 0, xPosition <= plotFrame.size.width,
              let date: Date = proxy.value(atX: xPosition, as: Date.self) else { return }
        selectedDate = date
    }

    private func legendItem(title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func projectionMetric(title: String, value: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(renderAmount(value))
                .font(.headline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayoutMetrics.contentGap)
        .padding(.vertical, 12)
        .liquidGlassPill(padding: 0, tint: tint)
    }

    private func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
