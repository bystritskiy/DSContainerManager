import SwiftUI

struct CircularGaugeView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    let unit: String

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
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: fraction)

                VStack(spacing: 2) {
                    Text(String(format: "%.0f", value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
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

struct LinearGaugeView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    let subtitle: String?

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
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.1f%%", fraction * 100))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))

                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * fraction)
                        .animation(.easeInOut(duration: 0.5), value: fraction)
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
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            CircularGaugeView(title: "CPU", value: 38, color: .blue)
            CircularGaugeView(title: "RAM", value: 60, color: .green)
            CircularGaugeView(title: "Disk", value: 75, color: .orange)
        }

        LinearGaugeView(title: "Volume 1", value: 5.6, maxValue: 8.0, color: .blue, subtitle: "5.6 TB / 8.0 TB")
        LinearGaugeView(title: "Volume 2", value: 1.2, maxValue: 4.0, color: .green, subtitle: "1.2 TB / 4.0 TB")
    }
    .padding()
}
