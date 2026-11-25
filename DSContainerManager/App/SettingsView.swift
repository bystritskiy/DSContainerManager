import ComposableArchitecture
import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                if let connection = store.activeConnection {
                    Section("Connected NAS") {
                        let hostAndPort = connection.host + ":" + String(connection.port)
                        LabeledContent("Name", value: connection.name)
                            .accessibilityLabel("NAS Name: \(connection.name)")
                        LabeledContent("Host", value: hostAndPort)
                            .accessibilityLabel("Host: \(connection.host), Port: " + String(connection.port))
                        LabeledContent("User", value: connection.username)
                            .accessibilityLabel("Username: \(connection.username)")
                        if let lastConnected = connection.lastConnected {
                            LabeledContent("Connected", value: lastConnected.relativeString)
                                .accessibilityLabel("Last connected \(lastConnected.relativeString)")
                        }
                    }
                }

                Section {
                    Toggle("Stopped Containers", isOn: $store.containerAlertsEnabled.sending(\.containerAlertsToggled))
                } header: {
                    Text("Notifications")
                } footer: {
                    if store.notificationsDenied {
                        Button("Allow notifications in Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .font(.footnote)
                    } else {
                        Text("Checked in the background when iOS allows, so alerts can be a few minutes late.")
                    }
                }

                Section {
                    Button("Disconnect", role: .destructive) {
                        store.send(.disconnect)
                    }
                    .accessibilityHint("Disconnect from the current NAS")
                }

                Section("About") {
                    // Read from the bundle so these never drift from MARKETING_VERSION / CURRENT_PROJECT_VERSION.
                    LabeledContent("Version", value: Self.versionString)
                    Link(destination: Self.issuesURL) {
                        Label("Report a Problem", systemImage: "exclamationmark.bubble")
                    }
                    Link(destination: Self.reviewURL) {
                        Label("Rate DSContainer", systemImage: "star")
                    }
                    Link(destination: Self.privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private static let issuesURL = URL(string: "https://github.com/bystritskiy/DSContainerManager/issues")!
    private static let reviewURL = URL(string: "https://apps.apple.com/app/id6786813488?action=write-review")!
    private static let privacyURL = URL(string: "https://dscontainer.app/privacy.html")!

    private static var versionString: String {
        let version = bundleValue("CFBundleShortVersionString")
        let build = bundleValue("CFBundleVersion")
        return "\(version) (\(build))"
    }

    private static func bundleValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        },
    )
}
