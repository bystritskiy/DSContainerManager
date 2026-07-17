import SwiftUI

struct CircularGaugeGroupView: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: Double
        let color: Color
        var unit: String = "%"

        init(title: String, value: Double, color: Color, unit: String = "%") {
            id = title
            self.title = title
            self.value = value
            self.color = color
            self.unit = unit
        }
    }

    let items: [Item]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 20) {
                ForEach(items) { item in
                    accessibleGauge(item)
                }
            }
        } else {
            HStack(spacing: 24) {
                ForEach(items) { item in
                    CircularGaugeView(
                        title: item.title,
                        value: item.value,
                        color: item.color,
                        unit: item.unit,
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func accessibleGauge(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    gaugeValue(item)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                    gaugeValue(item)
                }
            }

            ProgressView(value: min(max(item.value, 0), 100), total: 100)
                .tint(item.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title): \(String(format: "%.0f", item.value))\(item.unit)")
    }

    private func gaugeValue(_ item: Item) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(String(format: "%.0f", item.value))
                .font(.title2.bold())
                .monospacedDigit()
                .contentTransition(.numericText(value: item.value))
            Text(item.unit)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CircularGaugeGroupView(items: [
        .init(title: "CPU", value: 38, color: .blue),
        .init(title: "RAM", value: 60, color: .green),
        .init(title: "Disk", value: 75, color: .orange),
    ])
    .padding()
}
