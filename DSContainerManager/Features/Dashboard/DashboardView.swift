import ComposableArchitecture
import SwiftUI

struct DashboardView: View {
    let store: StoreOf<DashboardFeature>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isLoading, store.systemUtilization == nil {
                    loadingContent
                } else if let error = store.error, store.systemUtilization == nil {
                    ErrorBannerView(error) {
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
            .onDisappear {
                store.send(.stopPolling)
            }
        }
    }

    private var dashboardContent: some View {
        AdaptiveCardGrid {
            // System Gauges
            systemGaugesSection

            // Container Summary
            containerSummaryCard

            // Storage
            if let storageInfo = store.storageInfo {
                storageSection(storageInfo)
            }

            // Running containers preview
            if !store.containers.isEmpty {
                runningContainersSection
            }
        }
        .padding()
    }

    private var systemGaugesSection: some View {
        CircularGaugeGroupView(items: systemGaugeItems)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var systemGaugeItems: [CircularGaugeGroupView.Item] {
        var items = [
            CircularGaugeGroupView.Item(
                title: "CPU",
                value: store.cpuPercent,
                color: gaugeColor(for: store.cpuPercent),
            ),
            CircularGaugeGroupView.Item(
                title: "RAM",
                value: store.memoryPercent,
                color: gaugeColor(for: store.memoryPercent),
            ),
        ]

        if let disk = store.systemUtilization?.disk?.total {
            let value = Double(disk.utilization)
            items.append(.init(title: "Disk I/O", value: value, color: gaugeColor(for: value)))
        }

        return items
    }

    private var containerSummaryCard: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    containerSummaryTitle
                    Spacer()
                    containerSummaryTotal
                }

                VStack(alignment: .leading, spacing: 2) {
                    containerSummaryTitle
                    containerSummaryTotal
                }
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 24))

            layout {
                containerStat(count: store.runningCount, label: "Running", color: .green)
                containerStat(count: store.stoppedCount, label: "Stopped", color: .red)
                containerStat(
                    count: store.totalCount - store.runningCount - store.stoppedCount,
                    label: "Other",
                    color: .yellow,
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var containerSummaryTitle: some View {
        Text("Containers")
            .font(.headline)
    }

    private var containerSummaryTotal: some View {
        Text("\(store.totalCount) total")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
                    subtitle: "\(volume.usedSize.formattedBytes) / \(volume.totalSize.formattedBytes)",
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var runningContainersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Running")
                .font(.headline)

            if store.runningPreview.isEmpty {
                Text("No containers are running.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(store.runningPreview) { container in
                HStack(spacing: 8) {
                    Circle()
                        .fill(container.status.color)
                        .frame(width: 8, height: 8)
                    Text(container.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(container.image.components(separatedBy: "/").last ?? container.image)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Divider()

            Button {
                store.send(.showAllContainersTapped)
            } label: {
                HStack {
                    Text("All \(store.totalCount) containers")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.subheadline)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var loadingContent: some View {
        AdaptiveCardGrid {
            ForEach(0 ..< 4) { _ in
                SkeletonView(height: 80)
            }
        }
        .padding()
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
    DashboardView(
        store: Store(initialState: DashboardFeature.State()) {
            DashboardFeature()
        },
    )
}

#Preview("Duo inner display", traits: .fixedLayout(width: 951, height: 669)) {
    DashboardView(
        store: Store(initialState: DashboardFeature.State(
            baseURL: URL(string: "https://demo-nas.local:5001"),
            authSession: DemoMode.authSession,
            systemUtilization: .mock,
            storageInfo: .mock,
            containers: DockerContainer.mockList,
        )) {
            DashboardFeature()
        } withDependencies: {
            $0.synologyClient = .mock
            $0.continuousClock = ContinuousClock()
        },
    )
}
