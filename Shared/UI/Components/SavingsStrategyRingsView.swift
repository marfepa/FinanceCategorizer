import SwiftUI

struct SavingsStrategyRingsView: View {
    let snapshot: SavingsStrategySnapshot
    var size: CGFloat = 196

    var body: some View {
        ZStack {
            ForEach(ringSpecs, id: \.bucket) { spec in
                ZStack {
                    Circle()
                        .stroke(spec.color.opacity(0.16), lineWidth: spec.lineWidth)
                    Circle()
                        .trim(from: 0, to: spec.progress)
                        .stroke(
                            spec.color,
                            style: StrokeStyle(lineWidth: spec.lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: spec.diameter, height: spec.diameter)
                .animation(.spring(response: 0.55, dampingFraction: 0.86), value: spec.progress)
            }

            VStack(spacing: 3) {
                Text(ratioLabel)
                    .font(.system(size: size < 170 ? 17 : 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(LocalizedStringKey(snapshot.isOnTrack ? "strategy.status.onTrack" : "strategy.status.offTrack"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(snapshot.isOnTrack ? AppColors.income : AppColors.warning)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LocalizedStringKey("strategy.rings.accessibility"))
    }

    private var ratioLabel: String {
        snapshot.buckets
            .map { "\($0.targetPercent)" }
            .joined(separator: " · ")
    }

    private var ringSpecs: [RingSpec] {
        let lineWidth = max(11, size * 0.092)
        let diameters: [CGFloat] = [size, size - (lineWidth * 2.15), size - (lineWidth * 4.3)]
        return zip(SavingsAllocationBucket.allCases, diameters).map { bucket, diameter in
            let result = snapshot.result(for: bucket)
            let target = max(Double(result?.targetPercent ?? 1), 1)
            let actual = result?.actualPercent ?? 0
            return RingSpec(
                bucket: bucket,
                progress: snapshot.hasIncome ? min(max(actual / target, 0), 1) : 0,
                color: SavingsStrategyStatusStyle.color(result?.status ?? .under, bucket: bucket),
                lineWidth: lineWidth,
                diameter: diameter
            )
        }
    }
}

struct SavingsStrategyLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(SavingsAllocationBucket.allCases) { bucket in
                HStack(spacing: 6) {
                    Circle()
                        .fill(bucket.tintColor)
                        .frame(width: 7, height: 7)
                    Text(LocalizedStringKey(bucket.titleKey))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

enum SavingsStrategyStatusStyle {
    static func color(_ status: SavingsStrategyRangeStatus, bucket: SavingsAllocationBucket) -> Color {
        switch status {
        case .within:
            return bucket.tintColor
        case .over:
            return bucket == .investment ? AppColors.income : AppColors.expense
        case .under:
            return AppColors.warning
        }
    }

    static func key(_ status: SavingsStrategyRangeStatus, bucket: SavingsAllocationBucket) -> String {
        switch status {
        case .within: return "strategy.range.within"
        case .over: return bucket == .investment ? "strategy.range.above" : "strategy.range.over"
        case .under: return "strategy.range.under"
        }
    }
}

extension SavingsAllocationBucket {
    var tintColor: Color {
        switch self {
        case .needs: return AppColors.neutral
        case .wants: return AppColors.warning
        case .investment: return AppColors.income
        }
    }
}

private extension SavingsStrategyRingsView {
    struct RingSpec {
        let bucket: SavingsAllocationBucket
        let progress: CGFloat
        let color: Color
        let lineWidth: CGFloat
        let diameter: CGFloat
    }
}
