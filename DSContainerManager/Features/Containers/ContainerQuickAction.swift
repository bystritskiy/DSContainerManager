import SwiftUI

/// The lifecycle actions that make sense for a container in its current state,
/// shared by the list's swipe actions and context menus.
struct ContainerQuickAction: Identifiable, Equatable {
    let action: ContainerAction
    let title: String
    let systemImage: String
    let tint: Color

    var id: String {
        action.rawValue
    }

    static let start = ContainerQuickAction(action: .start, title: "Start", systemImage: "play.fill", tint: .green)
    static let stop = ContainerQuickAction(action: .stop, title: "Stop", systemImage: "stop.fill", tint: .red)
    static let restart = ContainerQuickAction(action: .restart, title: "Restart", systemImage: "arrow.clockwise", tint: .orange)
    /// Docker refuses to start a paused container; it has to be unpaused.
    static let resume = ContainerQuickAction(action: .unpause, title: "Resume", systemImage: "play.fill", tint: .green)

    static func available(for status: ContainerStatus) -> [ContainerQuickAction] {
        switch status {
        case .running: [.stop, .restart]
        case .paused: [.resume, .stop]
        case .restarting: [.stop]
        case .stopped, .created, .dead, .unknown: [.start]
        }
    }
}
