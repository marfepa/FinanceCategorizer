import SwiftUI

struct SavingsStrategyRingsView: View {
    let snapshot: SavingsStrategySnapshot
    var size: CGFloat = 196

    var body: some View {
        ZStack {
            ForEach(ringSpecs, id: \.bucket) { spec in
                ZStack {
                    Circle()
                        .stroke(spec.color.opacity(0.14), lineWidth: spec.lineWidth)
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

            VStack(spacing: 2) {
                Text(ratioLabel)
                    .font(.system(size: size < 170 ? 18 : 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(LocalizedStringKey(snapshot.isOnTrack ? "strategy.status.onTrack" : "strategy.status.offTrack"))
                    .font(.caption.weight(.medium))
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
        let widths: [CGFloat] = [size * 0.085, size * 0.085, size * 0.085]
        let diameters: [CGFloat] = [size, size * 0.74, size * 0.48]
        return zip(SavingsAllocationBucket.allCases, zip(widths, diameters)).map { bucket, metrics in
            let result = snapshot.result(for: bucket)
            let target = max(Double(result?.targetPercent ?? 1), 1)
            let actual = result?.actualPercent ?? 0
            let rawProgress = min(max(actual / target, 0), 1)
            let color: Color
            if result?.status == .over {
                color = AppColors.expense
            } else if result?.status == .under {
                color = AppColors.warning
            } else {
                color = bucket.tintColor
            }
            return RingSpec(
                bucket: bucket,
                progress: snapshot.hasIncome ? rawProgress : 0,
                color: color,
                lineWidth: metrics.0,
                diameter: metrics.1
            )
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
