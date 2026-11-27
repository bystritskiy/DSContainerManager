import ComposableArchitecture
import SwiftUI

struct ConnectionFormView: View {
    @Bindable var store: StoreOf<ConnectionFormFeature>
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, host, username, password
    }

    /// Left empty, the name falls back to the host, so show that as the hint.
    private var namePlaceholder: String {
        let host = HostAddress(parsing: store.host).host
        return host.isEmpty ? "Name" : host
    }

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Name", text: $store.name, prompt: Text(namePlaceholder))
                    .textContentType(.organizationName)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .host }

                TextField("Host or IP", text: $store.host)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .host)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .username }

                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", value: $store.port, format: .number.grouping(.never))
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
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField("Password", text: $store.password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit {
                        if store.isValid {
                            store.send(.saveButtonTapped)
                        }
                    }
            }

            if store.useHTTPS {
                Section {
                    Toggle("Trust Self-Signed Certificate", isOn: $store.trustSelfSignedCert)
                } footer: {
                    Text("Turn on if your NAS uses DSM's default certificate.")
                }
            }
        }
        .animation(.default, value: store.useHTTPS)
        .onChange(of: focusedField) { previous, _ in
            if previous == .host {
                store.send(.hostEditingEnded)
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
                    name: "NAS",
                    host: "192.168.1.70",
                    port: 5000,
                    useHTTPS: false,
                    username: "admin",
                    password: "",
                    trustSelfSignedCert: false,
                ),
            ) {
                ConnectionFormFeature()
            },
        )
    }
}
