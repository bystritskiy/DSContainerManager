import ComposableArchitecture
import SwiftUI

struct ConnectionFormView: View {
    @Bindable var store: StoreOf<ConnectionFormFeature>

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Name", text: $store.name)
                    .textContentType(.organizationName)

                TextField("Host or IP", text: $store.host)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", value: $store.port, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                Toggle("Use HTTPS", isOn: $store.useHTTPS)
            }

            Section("Authentication") {
                TextField("Username", text: $store.username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $store.password)
                    .textContentType(.password)

                Toggle("Two-Factor Authentication", isOn: $store.use2FA)
            }

            Section {
                Toggle("Trust Self-Signed Certificate", isOn: $store.trustSelfSignedCert)
            } header: {
                Text("Security")
            } footer: {
                Text("Enable this if your NAS uses a self-signed SSL certificate.")
            }
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    store.send(.cancelButtonTapped)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.send(.saveButtonTapped)
                }
                .disabled(!store.isValid)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionFormView(
            store: Store(
                initialState: ConnectionFormFeature.State(
                    mode: .add,
                    name: "",
                    host: "",
                    port: 5000,
                    useHTTPS: false,
                    username: "admin",
                    password: "",
                    use2FA: false,
                    trustSelfSignedCert: false
                )
            ) {
                ConnectionFormFeature()
            }
        )
    }
}
