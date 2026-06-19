# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

iOS app (SwiftUI) for managing Docker containers and Compose projects on a Synology NAS via the DSM WebAPI. Xcode project (not SPM package). iPhone-only, iOS/macOS deployment target 26.0, Swift 5.0. Bundle ID `com.bystritski.DSContainerManager`.

## Build / Run

No test target currently exists. Use Xcode (`open DSContainerManager.xcodeproj`) or xcodebuild:

```bash
# Build for simulator
xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -skipMacroValidation build

# Clean
xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager clean
```

Toolchain: requires Xcode 27 (iOS 26 SDK). `-skipMacroValidation` is needed
for CLI builds because TCA's SPM macros (ComposableArchitecture, swift-case-paths,
swift-dependencies, swift-perception) otherwise require an interactive trust prompt;
opening the project once in the Xcode GUI and approving the macros removes the need.
Simulators are iPhone 17-series (iPhone 16 no longer exists in Xcode 27).

Swift Package dependencies (resolved automatically by Xcode):
- `pointfreeco/swift-composable-architecture` — TCA (`ComposableArchitecture`, `Dependencies`, `DependenciesMacros`)
- `pointfreeco/swift-tagged` — `Tagged<Tag, Value>` strong-typed IDs

## Architecture

**TCA everywhere.** Every screen is a `@Reducer` with `@ObservableState`, an `Action` enum, and a `CancelID` enum for in-flight effect cancellation. Parent features compose children via `Scope` and forward delegate actions (e.g. `ContainerListFeature` listens for `.detail(.presented(.delegate(.containerUpdated(...))))`).

**Top-level composition** — `AppFeature` (`DSContainerManager/App/AppFeature.swift`) owns auth + connection state and five child feature states: `connectionList`, `dashboard`, `containerList`, `projectList`, `systemMonitor`. When a connection is established (`.connectionList(.delegate(.connectionEstablished))`), `applyConnection(...)` injects `baseURL`/`authSession` into each child and kicks off their `.onAppear`. `.disconnect` must cancel every feature's polling + in-flight action effects explicitly by `CancelID` — the list in `AppFeature` is the source of truth; add to it when you add new cancellables.

**Routing** — `AppRootView` chooses between `ConnectionListView` (disconnected), `MainTabView` (iPhone compact), and `SidebarNavigationView` (iPad / macOS regular width).

### Core layer (`DSContainerManager/Core/`)

- **`Clients/SynologyAPIClient.swift`** — `@DependencyClient` interface. All endpoints are `@Sendable` closures taking `(baseURL, AuthSession, ...)`.
- **`Clients/SynologyAPILive.swift`** — live implementation. All Synology calls go through `webapi/auth.cgi` (login/logout) or `webapi/entry.cgi` (everything else) as query-string GETs. Auth params are added via `authenticatedParams(...)` which injects `_sid` + `SynoToken`. `SynologySessionDelegate` trusts self-signed certs (required for typical NAS deployments). Responses are wrapped in `SynologyResponse<T>` — `decodeResponse` checks `.success` and maps `error.code` via `SynologyAPIError.fromErrorCode`. Logs and container resources have custom decoders because their payload shapes differ.
- **`Clients/SynologyAPIMock.swift`** — `previewValue` used by SwiftUI previews.
- **`Clients/ConnectionStore.swift`** — SwiftData-backed store for `NASConnection`. `@Model` class + `ConnectionProfile` `Sendable` snapshot — reducers only use the profile; the `@Model` doesn't cross actor boundaries.
- **`Clients/KeychainClient.swift`** — stores per-connection passwords and a single active `SavedSession` (session + connection UUID) so 2FA isn't re-required each launch. `AppFeature.restoreSavedSession()` validates by calling `getSystemUtilization` before trusting it.
- **`Clients/BackgroundMonitor.swift`** — `BGTaskScheduler` registration (identifier `com.dscontainermanager.container-health-check`, iOS-only via `#if os(iOS)`) and `UNUserNotificationCenter` setup. Call `registerTasks()` from `DSContainerManagerApp.init` — it must run before the scene is created.
- **`Models/SynologyTypes.swift`** — `Tagged` ID types (`ContainerID`, `ProjectID`, `SessionID`, `ConnectionID`) and the `ContainerStatus` / `ProjectStatus` / `ContainerAction` / `ProjectAction` enums that drive the API method dispatch in `SynologyAPILive`.

### Features (`DSContainerManager/Features/`)

One folder per tab (`Connection`, `Dashboard`, `Containers`, `Projects`, `SystemMonitor`), each containing a `*Feature.swift` (reducer) and `*View.swift` (SwiftUI). Containers and Projects additionally have a `*DetailFeature`/`*DetailView` presented via `@Presents`.

### Polling pattern

List/detail features poll via `clock.timer(interval:)` with cancellable effects. Intervals in use:
- Dashboard: 10s (`DashboardFeature.CancelID.polling`)
- Container list: 10s (`ContainerListFeature.CancelID.polling`)
- Container detail resources: 5s (`ContainerDetailFeature.CancelID.resourcePolling`)
- System monitor: varies per `SystemMonitorFeature`

Always `.cancellable(id: ..., cancelInFlight: true)` for both one-shot fetches and polling loops. Per-item actions (container/project start/stop) use `CancelID.action(String)` keyed by the item ID so repeated taps cancel in-flight requests and appear in `pendingActionIDs` for UI spinners.

## Conventions

- Reducer bodies are `nonisolated var body` and use `@Dependency(\.synologyClient)` / `\.continuousClock` / `\.keychainClient` / `\.connectionStore` / `\.backgroundMonitor`.
- Error types: `SynologyAPIError` (use `.fromErrorCode` when decoding Synology error payloads; check `.isSessionError` when deciding to force reconnect).
- `#if DEBUG` `print(...)` statements are used for API response tracing — keep new ones behind `#if DEBUG`.
- `#if os(iOS)` / `#if os(macOS)` guard platform-specific code (BackgroundTasks, keyboard shortcuts, sidebar column widths). `SUPPORTED_PLATFORMS` is currently `iphoneos iphonesimulator`, but the source keeps macOS guards for future expansion.
