import Charts
import ComposableArchitecture
import SwiftUI

struct SystemMonitorView: View {
    let store: StoreOf<SystemMonitorFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isLoading && store.currentUtilization == nil {
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
                    unit: "%"
                )
            }

            // Memory Chart
            if !store.memoryHistory.isEmpty {
                TimeSeriesChartView(
                    title: "Memory Usage",
                    data: store.memoryHistory,
                    valuePath: \.memoryPercent,
                    color: .green,
                    unit: "%"
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
        .padding()
    }

    private func currentValuesSection(_ util: SystemUtilization) -> some View {
        HStack(spacing: 24) {
            CircularGaugeView(
                title: "CPU",
                value: util.cpu.totalPercent,
                color: gaugeColor(for: util.cpu.totalPercent)
            )
            CircularGaugeView(
                title: "RAM",
                value: util.memory.usagePercent,
                color: gaugeColor(for: util.memory.usagePercent)
            )

            VStack(spacing: 4) {
                Text(util.memory.usedReal.formattedKilobytes)
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("of \(util.memory.totalReal.formattedKilobytes)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var networkChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network")
                .font(.headline)

            Chart {
                ForEach(store.networkHistory) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("RX", snapshot.networkRx)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)

                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("TX", snapshot.networkTx)
                    )
                    .foregroundStyle(.green)
                    .symbol(.triangle)
                }
            }
            .chartForegroundStyleScale([
                "Download": Color.blue,
                "Upload": Color.green,
            ])
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute().second())
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                        subtitle: "\(volume.usedSize.formattedBytes) / \(volume.totalSize.formattedBytes) — \(volume.freeSize.formattedBytes) free"
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
                        Label(volume.status, systemImage: volume.status == "normal" ? "checkmark.circle" : "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(volume.status == "normal" ? .green : .yellow)

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
        if value >= 90 { return .red }
        if value >= 70 { return .orange }
        return .blue
    }
}

#Preview {
    SystemMonitorView(
        store: Store(initialState: SystemMonitorFeature.State()) {
            SystemMonitorFeature()
        }
    )
}
