# Repository Guidelines

## Project Structure & Module Organization
`DSContainerManager/` contains the app code. `App/` holds root composition and navigation, `Core/` contains API clients, models, extensions, and widget support, `Features/` groups TCA reducers and views by tab (`Connection`, `Dashboard`, `Containers`, `Projects`, `SystemMonitor`), and `SharedUI/` stores reusable SwiftUI components. Visual assets live in `Assets.xcassets/`. Project settings are in `DSContainerManager.xcodeproj/`, and Swift package pins are tracked in `DSContainerManager.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Build, Test, and Development Commands
- `open DSContainerManager.xcodeproj` opens the project in Xcode.
- `xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager -destination 'platform=iOS Simulator,name=iPhone 16' build` builds the app for the iOS simulator.
- `xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager clean` removes build artifacts before a fresh build.

There is no test target in the repository yet, so a clean simulator build is the current baseline validation step.

## Coding Style & Naming Conventions
Use Swift and SwiftUI with the existing TCA structure. Follow Xcode’s default formatting: 4-space indentation, one type per file, `UpperCamelCase` for types, and `lowerCamelCase` for properties, methods, and enum cases. Keep feature files paired as `FeatureNameFeature.swift` and `FeatureNameView.swift`. Reducers in this repo use `@Reducer`, `@ObservableState`, dependency injection via `@Dependency`, and explicit `CancelID` cases for cancellable effects.

## Testing Guidelines
When adding tests, create an XCTest target and mirror the app structure, for example `Tests/Features/Containers/ContainerListFeatureTests.swift`. Prefer reducer-focused coverage for loading, polling, and cancellation behavior, plus targeted client decoding tests for Synology API models. Until tests exist, manually smoke-test connection setup, dashboard refresh, and container/project actions after each change.

## Commit & Pull Request Guidelines
Recent commits use short, imperative subjects such as `Sort containers and projects by name` and `Restore saved auth session on launch`. Keep commits focused on one behavioral change. Pull requests should describe the user-facing impact, note any Synology API or auth changes, link related issues, and include screenshots for UI updates made in SwiftUI views.

## Architecture Notes
This app is TCA-first. `AppFeature` coordinates connection state and fans `baseURL` plus `authSession` into child features. If you add a new polling or in-flight effect, register and cancel it consistently so disconnects fully stop background work.
