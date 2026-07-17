import ComposableArchitecture
import SwiftUI

struct ConnectionListView: View {
    @Bindable var store: StoreOf<ConnectionFeature>
    @Environment(\.startDemoMode) private var startDemoMode
    @State private var otpCode: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.connections.isEmpty, !store.isLoading {
                    EmptyStateView(
                        icon: "network",
                        title: "No Connections",
                        message: "Add your Synology NAS connection to get started.",
                        actionTitle: "Add NAS",
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
                            Button {
                                store.send(.connectTapped(profile))
                            } label: {
                                ConnectionRowView(
                                    profile: profile,
                                    isConnecting: store.loginInProgressId == profile.id,
                                )
                            }
                            .buttonStyle(FluidPressButtonStyle())
                            .disabled(store.loginInProgressId != nil)
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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button {
                        startDemoMode()
                    } label: {
                        Label("Try Demo Mode", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Text("Explore the app with sample data — no NAS required.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding([.horizontal, .bottom])
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
                set: { if !$0 { store.send(.dismissOTPPrompt) } },
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
        },
    )
}
