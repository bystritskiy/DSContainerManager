import ComposableArchitecture
import SwiftUI

struct ConnectionListView: View {
    @Bindable var store: StoreOf<ConnectionFeature>
    @State private var otpCode: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.connections.isEmpty && !store.isLoading {
                    EmptyStateView(
                        icon: "network",
                        title: "No Connections",
                        message: "Add your Synology NAS connection to get started.",
                        actionTitle: "Add NAS"
                    ) {
                        store.send(.addButtonTapped)
                    }
                } else {
                    List {
                        if let error = store.error {
                            ErrorBannerView(error) {
                                store.send(.loadConnections)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        ForEach(store.connections) { profile in
                            ConnectionRowView(
                                profile: profile,
                                isConnecting: store.loginInProgressId == profile.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.send(.connectTapped(profile))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.send(.deleteConnection(profile.id))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    store.send(.editButtonTapped(profile))
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Connections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $store.scope(state: \.connectionForm, action: \.connectionForm)) { formStore in
                NavigationStack {
                    ConnectionFormView(store: formStore)
                }
            }
            .alert("Verification Code Required", isPresented: Binding(
                get: { store.otpPrompt != nil },
                set: { if !$0 { store.send(.dismissOTPPrompt) } }
            )) {
                TextField("000000", text: $otpCode)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()

                Button("Submit") {
                    if let prompt = store.otpPrompt {
                        store.send(.otpSubmitted(otpCode, prompt.connectionProfile, prompt.password))
                        otpCode = ""
                    }
                }

                Button("Cancel", role: .cancel) {
                    otpCode = ""
                    store.send(.dismissOTPPrompt)
                }
            } message: {
                Text("Enter the code from your authenticator app to finish signing in.")
            }
            .onAppear {
                if store.connections.isEmpty {
                    store.send(.loadConnections)
                }
            }
        }
    }
}

#Preview {
    ConnectionListView(
        store: Store(initialState: ConnectionFeature.State()) {
            ConnectionFeature()
        }
    )
}
