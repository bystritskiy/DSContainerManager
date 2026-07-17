import SwiftUI

struct CircularGaugeView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    let unit: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, value: Double, maxValue: Double = 100, color: Color = .blue, unit: String = "%") {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.unit = unit
    }

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round),
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion
                            ? .easeOut(duration: 0.15)
                            : .spring(response: 0.4, dampingFraction: 1),
                        value: fraction,
                    )

                VStack(spacing: 2) {
                    Text(String(format: "%.0f", value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: value))
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(String(format: "%.0f", value))\(unit)")
        .accessibilityValue(String(format: "%.0f percent", fraction * 100))
    }
}

#Preview {
    HStack(spacing: 24) {
        CircularGaugeView(title: "CPU", value: 38, color: .blue)
        CircularGaugeView(title: "RAM", value: 60, color: .green)
        CircularGaugeView(title: "Disk", value: 75, color: .orange)
    }
    .padding()
}
