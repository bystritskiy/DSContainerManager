import Charts
import SwiftUI

struct TimeSeriesChartView: View {
    let title: String
    let data: [ResourceSnapshot]
    let valuePath: KeyPath<ResourceSnapshot, Double>
    let color: Color
    let unit: String
    var maxY: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let latest = data.last {
                    Text(Self.format(latest[keyPath: valuePath], unit: unit))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Chart(data) { snapshot in
                LineMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value(title, snapshot[keyPath: valuePath]),
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value(title, snapshot[keyPath: valuePath]),
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.2), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                )
                .interpolationMethod(.catmullRom)

                // Mark the latest reading; with a single sample it's the only thing a line chart can draw.
                if snapshot.id == data.last?.id {
                    PointMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value(title, snapshot[keyPath: valuePath]),
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                }
            }
            .chartYScale(domain: 0 ... maxY)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute().second())
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text("\(Int(val))\(unit)")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private static func format(_ value: Double, unit: String) -> String {
        if unit == "%" {
            return (value / 100).formatted(.percent.precision(.fractionLength(1)))
        }
        return value.formatted(.number.precision(.fractionLength(1))) + unit
    }
}

#Preview {
    let data = (0 ..< 30).map { offset in
        ResourceSnapshot(
            timestamp: Date.now.addingTimeInterval(Double(-30 + offset) * 5),
            cpuPercent: Double.random(in: 20 ... 60),
            memoryPercent: Double.random(in: 40 ... 70),
        )
    }

    VStack(spacing: 16) {
        TimeSeriesChartView(
            title: "CPU Usage",
            data: data,
            valuePath: \.cpuPercent,
            color: .blue,
            unit: "%",
        )
        TimeSeriesChartView(
            title: "Memory Usage",
            data: data,
            valuePath: \.memoryPercent,
            color: .green,
            unit: "%",
        )
    }
    .padding()
}
