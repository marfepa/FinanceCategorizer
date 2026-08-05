import SwiftUI

struct InChartCalloutOverlayItem: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: String
    let color: Color?

    init(label: String, value: String, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
}

struct InChartCalloutOverlay: View {
    let title: String
    let items: [InChartCalloutOverlayItem]
    var alignment: Alignment = .topLeading

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            // Header badge
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.trailing, items.isEmpty ? 0 : 4)

            if !items.isEmpty {
                Divider()
                    .frame(height: 14)
                    .foregroundStyle(.white.opacity(0.2))

                HStack(spacing: AppSpacing.small) {
                    ForEach(items) { item in
                        HStack(spacing: 5) {
                            if let color = item.color {
                                Circle()
                                    .fill(color)
                                    .frame(width: 5, height: 5)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(item.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(item.value)
                                    .font(.caption2.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .allowsHitTesting(false)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: title)
        .accessibilityElement(children: .combine)
    }
}
