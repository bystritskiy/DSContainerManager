import ComposableArchitecture
import SwiftUI

struct DashboardView: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isLoading && store.systemUtilization == nil {
                    loadingContent
                } else if let error = store.error, store.systemUtilization == nil {
                    ErrorBanner(error) {
                        store.send(.refresh)
                    }
                    .padding()
                } else {
                    dashboardContent
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                store.send(.refresh)
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        VStack(spacing: 16) {
            // System Gauges
            systemGaugesSection

            // Container Summary
            containerSummaryCard

            // Storage
            if let storageInfo = store.storageInfo {
                storageSection(storageInfo)
            }

            // Top Containers
            if !store.containers.isEmpty {
                topContainersSection
            }
        }
        .padding()
    }

    private var systemGaugesSection: some View {
        HStack(spacing: 24) {
            CircularGaugeView(
                title: "CPU",
                value: store.cpuPercent,
                color: gaugeColor(for: store.cpuPercent)
            )

            CircularGaugeView(
                title: "RAM",
                value: store.memoryPercent,
                color: gaugeColor(for: store.memoryPercent)
            )

            if let disk = store.systemUtilization?.disk?.total {
                CircularGaugeView(
                    title: "Disk I/O",
                    value: Double(disk.utilization),
                    color: gaugeColor(for: Double(disk.utilization))
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var containerSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Containers")
                    .font(.headline)
                Spacer()
                Text("\(store.totalCount) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                containerStat(count: store.runningCount, label: "Running", color: .green)
                containerStat(count: store.stoppedCount, label: "Stopped", color: .red)
                containerStat(
                    count: store.totalCount - store.runningCount - store.stoppedCount,
                    label: "Other",
                    color: .yellow
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func containerStat(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func storageSection(_ info: StorageInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.headline)

            ForEach(info.volumes) { volume in
                LinearGaugeView(
                    title: volume.path,
                    value: volume.usagePercent,
                    maxValue: 100,
                    color: gaugeColor(for: volume.usagePercent),
                    subtitle: "\(volume.usedSize.formattedBytes) / \(volume.totalSize.formattedBytes)"
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var topContainersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Containers")
                .font(.headline)

            ForEach(store.containers.prefix(6)) { container in
                HStack {
                    Circle()
                        .fill(container.status.color)
                        .frame(width: 8, height: 8)
                    Text(container.name)
                        .font(.subheadline)
                    Spacer()
                    Text(container.image.components(separatedBy: "/").last ?? container.image)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    StatusBadge(containerStatus: container.status)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var loadingContent: some View {
        VStack(spacing: 16) {
            ForEach(0..<4) { _ in
                SkeletonView(height: 80)
            }
        }
        .padding()
    }

    private func gaugeColor(for value: Double) -> Color {
        if value >= 90 { return .red }
        if value >= 70 { return .orange }
        return .blue
    }
}

#Preview {
    DashboardView(
        store: Store(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
    )
}
