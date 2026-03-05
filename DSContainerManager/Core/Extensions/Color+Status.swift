import SwiftUI

extension ContainerStatus {
    var color: Color {
        switch self {
        case .running: .green
        case .stopped: .red
        case .paused: .yellow
        case .restarting: .orange
        case .created: .blue
        case .dead: .red
        case .unknown: .gray
        }
    }

    var iconName: String {
        switch self {
        case .running: "play.circle.fill"
        case .stopped: "stop.circle.fill"
        case .paused: "pause.circle.fill"
        case .restarting: "arrow.clockwise.circle.fill"
        case .created: "plus.circle.fill"
        case .dead: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

extension ProjectStatus {
    var color: Color {
        switch self {
        case .running: .green
        case .stopped: .red
        case .partiallyRunning: .yellow
        case .unknown: .gray
        }
    }

    var iconName: String {
        switch self {
        case .running: "play.circle.fill"
        case .stopped: "stop.circle.fill"
        case .partiallyRunning: "exclamationmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}
