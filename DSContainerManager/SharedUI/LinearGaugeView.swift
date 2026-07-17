import SwiftUI

struct LinearGaugeView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    let subtitle: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, value: Double, maxValue: Double = 100, color: Color = .blue, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.subtitle = subtitle
    }

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    gaugeTitle
                    Spacer()
                    gaugeValue
                }

                VStack(alignment: .leading, spacing: 2) {
                    gaugeTitle
                    gaugeValue
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))

                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * fraction)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.15)
                                : .spring(response: 0.4, dampingFraction: 1),
                            value: fraction,
                        )
                }
            }
            .frame(height: 8)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(String(format: "%.1f", fraction * 100)) percent")
        .accessibilityValue(subtitle ?? "")
    }

    private var gaugeTitle: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
    }

    private var gaugeValue: some View {
        Text(String(format: "%.1f%%", fraction * 100))
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .contentTransition(.numericText(value: fraction))
    }
}

#Preview {
    VStack(spacing: 24) {
        LinearGaugeView(title: "Volume 1", value: 5.6, maxValue: 8.0, color: .blue, subtitle: "5.6 TB / 8.0 TB")
        LinearGaugeView(title: "Volume 2", value: 1.2, maxValue: 4.0, color: .green, subtitle: "1.2 TB / 4.0 TB")
    }
    .padding()
}
