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

                // Inline glyphs: Labels in a row get wide icon gaps that read as separate columns.
                Group {
                    let user = Image(systemName: "person")
                    if profile.useHTTPS {
                        Text("\(user) \(profile.username)   \(Image(systemName: "lock.fill")) HTTPS")
                    } else {
                        Text("\(user) \(profile.username)")
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
