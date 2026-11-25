import Charts
import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct ContainerDetailView: View {
    @Bindable var store: StoreOf<ContainerDetailFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingKillConfirmation = false
    @State private var showingLogExporter = false
    @State private var logExportDocument = ContainerLogsDocument()

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
            .id(store.selectedTab)
            .transition(.opacity)
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.15)
                : .spring(response: 0.32, dampingFraction: 1),
            value: store.selectedTab,
        )
        .sensoryFeedback(.selection, trigger: store.selectedTab)
        .navigationTitle(store.container.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.selectedTab == .logs {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        logExportDocument = ContainerLogsDocument(logs: store.logs)
                        showingLogExporter = true
                    } label: {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(store.logs.isEmpty)
                }
            }
        }
        .fileExporter(
            isPresented: $showingLogExporter,
            document: logExportDocument,
            contentType: .plainText,
            defaultFilename: "\(store.container.name)-logs",
        ) { _ in }
        .confirmationDialog(
            "Kill \(store.container.name)?",
            isPresented: $showingKillConfirmation,
            titleVisibility: .visible,
        ) {
            Button("Kill Container", role: .destructive) {
                store.send(.actionTapped(.kill))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The container process will be terminated immediately and may lose unsaved data.")
        }
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
                    .copyable(store.container.image)
                LabeledContent("Status", value: store.container.status.displayName)
                LabeledContent("Created", value: store.container.created.mediumDateTimeString)
            }

            if !store.container.ports.isEmpty {
                Section("Ports") {
                    ForEach(store.container.ports, id: \.self) { port in
                        portRow(port)
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
                            .copyable(volume.source)
                        }
                    }
                }

                if !detail.env.isEmpty {
                    Section("Environment") {
                        ForEach(detail.env, id: \.self) { env in
                            EnvironmentVariableRow(entry: env)
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
        .refreshable {
            await store.send(.refreshDetail).finish()
        }
    }

    /// Published TCP ports link straight to the service's web page on the NAS.
    @ViewBuilder
    private func portRow(_ port: DockerContainer.PortMapping) -> some View {
        if let host = store.baseURL?.host(), let url = port.webURL(host: host) {
            Link(destination: url) {
                HStack {
                    Text(port.displayString)
                        .font(.body.monospaced())
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "safari")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityHint("Opens \(url.absoluteString) in Safari")
            .copyable(url.absoluteString)
        } else {
            Text(port.displayString)
                .font(.body.monospaced())
        }
    }

    // MARK: - Logs Tab

    private var logsTab: some View {
        VStack(spacing: 0) {
            if !store.hasLoadedLogs {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.logs.isEmpty {
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
                    .refreshable {
                        await store.send(.refreshLogs).finish()
                    }
                    .onAppear {
                        if let lastLog = store.filteredLogs.last {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: store.logs.last?.id) {
                        // New lines arrived (refresh, or after Start/Restart): follow the tail.
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
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Resources and Actions Tabs

extension ContainerDetailView {
    private var resourcesTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let resources = store.currentResources {
                    // Current values
                    VStack(spacing: 16) {
                        CircularGaugeGroupView(items: [
                            .init(title: "CPU", value: resources.cpuPercent, color: .blue),
                            .init(title: "Memory", value: resources.memoryPercent, color: .green),
                        ])

                        Divider()

                        LabeledContent("Memory") {
                            Text(memorySummary(resources))
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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

    private func memorySummary(_ resources: ContainerResources) -> String {
        let used = resources.memoryUsage.formattedBytes
        guard resources.memoryLimit > 0 else { return used }
        return "\(used) of \(resources.memoryLimit.formattedBytes)"
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

                // Mark the latest reading; with a single sample it's the only thing a line chart can draw.
                if snapshot.id == store.resourceHistory.last?.id {
                    PointMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value(title, value(snapshot)),
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                }
            }
            .chartYScale(domain: 0 ... 100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute().second(), anchor: .top)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel(anchor: .trailing)
                    AxisGridLine()
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

            let status = store.container.status

            Section("Container Actions") {
                if status == .paused {
                    // Docker can't start a paused container; it has to be unpaused.
                    actionButton(title: "Resume", icon: "play.fill", color: .green, action: .unpause, enabled: true)
                } else {
                    actionButton(title: "Start", icon: "play.fill", color: .green, action: .start,
                                 enabled: !status.isActive)
                }
                actionButton(title: "Stop", icon: "stop.fill", color: .red, action: .stop,
                             enabled: status.isActive)
                actionButton(title: "Restart", icon: "arrow.clockwise", color: .orange, action: .restart,
                             enabled: status == .running)
                actionButton(title: "Pause", icon: "pause.fill", color: .yellow, action: .pause,
                             enabled: status == .running)
            }

            Section("Danger Zone") {
                actionButton(title: "Kill", icon: "xmark.circle.fill", color: .red, action: .kill,
                             enabled: status.isActive)
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: ContainerAction, enabled: Bool) -> some View {
        Button {
            if action == .kill {
                showingKillConfirmation = true
            } else {
                store.send(.actionTapped(action))
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    // Disabled buttons dim their text but not an explicit style, so dim the icon too.
                    .foregroundStyle(enabled ? color : .secondary)
                    .frame(width: 24)
                Text(title)
                Spacer()
                if store.pendingAction == action {
                    ProgressView()
                }
            }
        }
        .disabled(!enabled || store.isPerformingAction)
    }
}

private struct ContainerLogsDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]

    private let text: String

    init(text: String = "") {
        self.text = text
    }

    init(logs: [ContainerLog]) {
        text = logs
            .map { log in
                "\(log.timestamp.formatted(.iso8601)) [\(log.stream.rawValue)] \(log.text)"
            }
            .joined(separator: "\n") + "\n"
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// One `KEY=value` line. Values of likely secrets are masked until tapped, so tokens and
/// passwords don't sit in plain sight on screen (or in screenshots).
private struct EnvironmentVariableRow: View {
    let entry: String
    @State private var isRevealed = false

    private static let sensitiveMarkers = ["TOKEN", "SECRET", "PASSWORD", "PASSWD", "KEY", "CREDENTIAL", "AUTH"]

    private var name: String {
        String(entry.prefix { $0 != "=" })
    }

    private var isSensitive: Bool {
        let upperName = name.uppercased()
        return entry.contains("=") && Self.sensitiveMarkers.contains { upperName.contains($0) }
    }

    var body: some View {
        if isSensitive {
            Button {
                isRevealed.toggle()
            } label: {
                HStack {
                    Text(isRevealed ? entry : "\(name)=••••••••")
                        .font(.caption.monospaced())
                        .lineLimit(isRevealed ? nil : 2)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isRevealed ? "Hides the value" : "Shows the value")
        } else {
            Text(entry)
                .font(.caption.monospaced())
                .lineLimit(2)
        }
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

// MARK: - Copy

private extension View {
    /// Long-press to copy a value people often need elsewhere (image names, paths, URLs).
    func copyable(_ value: String) -> some View {
        contextMenu {
            Button {
                UIPasteboard.general.string = value
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}
