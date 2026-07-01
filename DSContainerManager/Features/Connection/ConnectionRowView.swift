import SwiftUI

struct ConnectionRowView: View {
    let profile: ConnectionProfile
    let isConnecting: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    if profile.isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(verbatim: "\(profile.host):\(profile.port)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label(profile.username, systemImage: "person")
                    if profile.useHTTPS {
                        Label("HTTPS", systemImage: "lock.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isConnecting {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ConnectionRowView(
            profile: ConnectionProfile(
                id: UUID(),
                name: "Home NAS",
                host: "192.168.1.10",
                port: 5001,
                useHTTPS: true,
                username: "admin",
                lastConnected: nil,
                isDefault: true,
                trustSelfSignedCert: true,
            ),
            isConnecting: false,
        )
        ConnectionRowView(
            profile: ConnectionProfile(
                id: UUID(),
                name: "Office NAS",
                host: "10.0.0.5",
                port: 5000,
                useHTTPS: false,
                username: "bogdan",
                lastConnected: nil,
                isDefault: false,
                trustSelfSignedCert: false,
            ),
            isConnecting: true,
        )
    }
}
