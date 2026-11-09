import ComposableArchitecture
import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    let store: StoreOf<AppFeature>

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
                    Button("Disconnect", role: .destructive) {
                        store.send(.disconnect)
                    }
                    .accessibilityHint("Disconnect from the current NAS")
                }

                Section("About") {
                    // Read from the bundle so these never drift from MARKETING_VERSION / CURRENT_PROJECT_VERSION.
                    LabeledContent("Version", value: Self.bundleValue("CFBundleShortVersionString"))
                    LabeledContent("Build", value: Self.bundleValue("CFBundleVersion"))
                }
            }
            .navigationTitle("Settings")
        }
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
