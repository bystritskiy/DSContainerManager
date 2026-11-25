import Charts
import ComposableArchitecture
import SwiftUI

struct SystemMonitorView: View {
    let store: StoreOf<SystemMonitorFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isLoading, store.currentUtilization == nil {
                    VStack(spacing: 16) {
                        ForEach(0 ..< 4) { _ in
                            SkeletonView(height: 200)
                        }
                    }
                    .padding()
                } else {
                    monitorContent
                }
            }
            .navigationTitle("System Monitor")
            .refreshable {
                store.send(.refresh)
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.onDisappear)
            }
        }
    }

    private var monitorContent: some View {
        VStack(spacing: 16) {
            if let error = store.error {
                ErrorBannerView(error) {
                    store.send(.refresh)
                }
            }

            AdaptiveCardGrid {
                cards
            }
        }
        .padding()
    }

    @ViewBuilder
    private var cards: some View {
        // Current values
        if let util = store.currentUtilization {
            currentValuesSection(util)
        }

        // CPU Chart
        if !store.cpuHistory.isEmpty {
            TimeSeriesChartView(
                title: "CPU Usage",
                data: store.cpuHistory,
                valuePath: \.cpuPercent,
                color: .blue,
                unit: "%",
            )
        }

        // Memory Chart
        if !store.memoryHistory.isEmpty {
            TimeSeriesChartView(
                title: "Memory Usage",
                data: store.memoryHistory,
                valuePath: \.memoryPercent,
                color: .green,
                unit: "%",
            )
        }

        // Network Chart
        if !store.networkHistory.isEmpty {
            networkChart
        }

        // Storage
        if let storage = store.storageInfo {
            storageSection(storage)
        }

        // Disk I/O
        if let disk = store.currentUtilization?.disk {
            diskSection(disk)
        }
    }

    private func currentValuesSection(_ util: SystemUtilization) -> some View {
        VStack(spacing: 16) {
            CircularGaugeGroupView(items: [
                .init(
                    title: "CPU",
                    value: util.cpu.totalPercent,
                    color: gaugeColor(for: util.cpu.totalPercent),
                ),
                .init(
                    title: "RAM",
                    value: util.memory.usagePercent,
                    color: gaugeColor(for: util.memory.usagePercent),
                ),
            ])

            Divider()

            LabeledContent("Physical Memory") {
                Text("\(util.memory.usedReal.formattedKilobytes) of \(util.memory.totalReal.formattedKilobytes)")
                    .monospacedDigit()
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var networkChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Network")
                    .font(.headline)
                Spacer()
                if let latest = store.networkHistory.last {
                    HStack(spacing: 10) {
                        Label(Self.rate(latest.networkRx), systemImage: "arrow.down")
                        Label(Self.rate(latest.networkTx), systemImage: "arrow.up")
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
            }

            Chart {
                // Separate series, or Charts joins download and upload into one zigzag line.
                ForEach(store.networkHistory) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Bytes per second", snapshot.networkRx),
                        series: .value("Direction", "Download"),
                    )
                    .foregroundStyle(by: .value("Direction", "Download"))
                    .interpolationMethod(.catmullRom)
                }
                ForEach(store.networkHistory) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Bytes per second", snapshot.networkTx),
                        series: .value("Direction", "Upload"),
                    )
                    .foregroundStyle(by: .value("Direction", "Upload"))
                    .interpolationMethod(.catmullRom)
                }
                if store.networkHistory.count == 1, let only = store.networkHistory.first {
                    PointMark(x: .value("Time", only.timestamp), y: .value("Bytes per second", only.networkRx))
                        .foregroundStyle(by: .value("Direction", "Download"))
                    PointMark(x: .value("Time", only.timestamp), y: .value("Bytes per second", only.networkTx))
                        .foregroundStyle(by: .value("Direction", "Upload"))
                }
            }
            .chartForegroundStyleScale([
                "Download": Color.blue,
                "Upload": Color.green,
            ])
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute().second())
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let bytes = value.as(Int64.self) {
                            Text(Self.rate(bytes))
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

    private static func rate(_ bytesPerSecond: Int64) -> String {
        "\(bytesPerSecond.formattedBytes)/s"
    }

    private func storageSection(_ info: StorageInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Volumes")
                .font(.headline)

            ForEach(info.volumes) { volume in
                VStack(spacing: 8) {
                    LinearGaugeView(
                        title: volume.path,
                        value: volume.usagePercent,
                        maxValue: 100,
                        color: gaugeColor(for: volume.usagePercent),
                        subtitle: "\(volume.usedSize.formattedBytes) / \(volume.totalSize.formattedBytes) — \(volume.freeSize.formattedBytes) free",
                    )

                    HStack(spacing: 16) {
                        if let temp = volume.temperature {
                            Label("\(temp)°C", systemImage: "thermometer")
                                .font(.caption)
                                .foregroundStyle(temp > 50 ? .red : .secondary)
                        }
                        if let driveType = volume.driveType {
                            Label(driveType, systemImage: "internaldrive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Label(
                            volume.status.capitalized,
                            systemImage: volume.status == "normal" ? "checkmark.circle" : "exclamationmark.triangle",
                        )
                        .font(.caption)
                        .foregroundStyle(volume.status == "normal" ? .green : .orange)

                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func diskSection(_ overview: DiskOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disk I/O")
                .font(.headline)

            ForEach(overview.disk) { disk in
                HStack {
                    Text(disk.displayName)
                        .font(.subheadline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Label("R: \(Int64(disk.readByte).formattedBytes)/s", systemImage: "arrow.down.circle")
                        Label("W: \(Int64(disk.writeByte).formattedBytes)/s", systemImage: "arrow.up.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func gaugeColor(for value: Double) -> Color {
        if value >= 90 {
            return .red
        }
        if value >= 70 {
            return .orange
        }
        return .blue
    }
}

#Preview {
    SystemMonitorView(
        store: Store(initialState: SystemMonitorFeature.State()) {
            SystemMonitorFeature()
        },
    )
}

#Preview("Duo inner display", traits: .fixedLayout(width: 951, height: 669)) {
    SystemMonitorView(
        store: Store(initialState: SystemMonitorFeature.State(
            baseURL: URL(string: "https://demo-nas.local:5001"),
            authSession: DemoMode.authSession,
        )) {
            SystemMonitorFeature()
        } withDependencies: {
            $0.synologyClient = .mock
            $0.continuousClock = ContinuousClock()
        },
    )
}
