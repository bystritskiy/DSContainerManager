import Charts
import ComposableArchitecture
import SwiftUI

struct ContainerDetailView: View {
    @Bindable var store: StoreOf<ContainerDetailFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $store.selectedTab.sending(\.tabSelected)) {
                ForEach(ContainerDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            Group {
                switch store.selectedTab {
                case .info:
                    infoTab
                case .logs:
                    logsTab
                case .resources:
                    resourcesTab
                case .actions:
                    actionsTab
                }
            }
        }
        .navigationTitle(store.container.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.stopResourcePolling)
        }
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        List {
            if let error = store.error {
                ErrorBannerView(error)
            }

            Section("General") {
                LabeledContent("Image", value: store.container.image)
                LabeledContent("Status", value: store.container.status.displayName)
                LabeledContent("Created", value: store.container.created.mediumDateTimeString)
                LabeledContent("State", value: store.container.state)
            }

            if !store.container.ports.isEmpty {
                Section("Ports") {
                    ForEach(store.container.ports, id: \.self) { port in
                        Text(port.displayString)
                            .font(.body.monospaced())
                    }
                }
            }

            if let detail = store.detail {
                if !detail.volumes.isEmpty {
                    Section("Volumes") {
                        ForEach(detail.volumes) { volume in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(volume.source)
                                    .font(.caption.monospaced())
                                Text("→ \(volume.destination)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(volume.mode)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if !detail.env.isEmpty {
                    Section("Environment") {
                        ForEach(detail.env, id: \.self) { env in
                            Text(env)
                                .font(.caption.monospaced())
                                .lineLimit(2)
                        }
                    }
                }

                if !detail.networks.isEmpty {
                    Section("Networks") {
                        ForEach(detail.networks, id: \.self) { network in
                            Text(network)
                        }
                    }
                }

                if let config = detail.hostConfig {
                    Section("Host Config") {
                        if let memory = config.memoryLimit {
                            LabeledContent("Memory Limit", value: memory.formattedBytes)
                        }
                        if let cpu = config.cpuShares {
                            LabeledContent("CPU Shares", value: "\(cpu)")
                        }
                        if let restart = config.restartPolicy {
                            LabeledContent("Restart Policy", value: restart)
                        }
                        if let network = config.networkMode {
                            LabeledContent("Network Mode", value: network)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logs Tab

    private var logsTab: some View {
        VStack(spacing: 0) {
            if store.logs.isEmpty {
                EmptyStateView(
                    icon: "text.alignleft",
                    title: "No Logs",
                    message: "No log entries available for this container.",
                )
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(store.filteredLogs) { log in
                            logRow(log)
                                .id(log.id)
                        }
                    }
                    .listStyle(.plain)
                    .font(.caption.monospaced())
                    .onAppear {
                        if let lastLog = store.filteredLogs.last {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .searchable(text: $store.logSearchText, prompt: "Search logs")
    }

    private func logRow(_ log: ContainerLog) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(log.timestamp.timeOnlyString)
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .leading)

            Rectangle()
                .fill(log.stream == .stderr ? Color.red : Color.green)
                .frame(width: 3)

            Text(log.text)
                .foregroundStyle(log.stream == .stderr ? .red : .primary)
        }
        .padding(.vertical, 1)
    }

    // MARK: - Resources Tab

    private var resourcesTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let resources = store.currentResources {
                    // Current values
                    HStack(spacing: 24) {
                        CircularGaugeView(
                            title: "CPU",
                            value: resources.cpuPercent,
                            color: .blue,
                        )
                        CircularGaugeView(
                            title: "Memory",
                            value: resources.memoryPercent,
                            color: .green,
                        )
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // Memory details
                    HStack {
                        LabeledContent("Used", value: resources.memoryUsage.formattedBytes)
                        Spacer()
                        LabeledContent("Limit", value: resources.memoryLimit.formattedBytes)
                    }
                    .font(.caption)
                    .padding(.horizontal)
                }

                // CPU chart
                if !store.resourceHistory.isEmpty {
                    chartSection(title: "CPU Usage", color: .blue) { snapshot in
                        snapshot.cpuPercent
                    }

                    chartSection(title: "Memory Usage", color: .green) { snapshot in
                        snapshot.memoryPercent
                    }
                }

                if store.resourceHistory.isEmpty, store.currentResources == nil {
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "No Data",
                        message: "Resource data will appear here once polling starts.",
                    )
                }
            }
            .padding()
        }
    }

    private func chartSection(title: String, color: Color, value: @escaping (ResourceSnapshot) -> Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Chart(store.resourceHistory) { snapshot in
                LineMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value(title, value(snapshot)),
                )
                .foregroundStyle(color)

                AreaMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value(title, value(snapshot)),
                )
                .foregroundStyle(color.opacity(0.1))
            }
            .chartYScale(domain: 0 ... 100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute().second())
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions Tab

    private var actionsTab: some View {
        List {
            if let error = store.error {
                ErrorBannerView(error)
            }

            Section("Container Actions") {
                actionButton(title: "Start", icon: "play.fill", color: .green, action: .start,
                             enabled: store.container.status != .running)
                actionButton(title: "Stop", icon: "stop.fill", color: .red, action: .stop,
                             enabled: store.container.status == .running)
                actionButton(title: "Restart", icon: "arrow.clockwise", color: .orange, action: .restart,
                             enabled: store.container.status == .running)
                actionButton(title: "Pause", icon: "pause.fill", color: .yellow, action: .pause,
                             enabled: store.container.status == .running)
            }

            Section("Danger Zone") {
                actionButton(title: "Kill", icon: "xmark.circle.fill", color: .red, action: .kill,
                             enabled: store.container.status == .running)
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: ContainerAction, enabled: Bool) -> some View {
        Button {
            store.send(.actionTapped(action))
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                Spacer()
                if store.isPerformingAction {
                    ProgressView()
                }
            }
        }
        .disabled(!enabled || store.isPerformingAction)
    }
}

#Preview {
    NavigationStack {
        ContainerDetailView(
            store: Store(
                initialState: ContainerDetailFeature.State(
                    container: DockerContainer.mockList[0],
                ),
            ) {
                ContainerDetailFeature()
            },
        )
    }
}
