# Repository Guidelines

## Project Structure & Module Organization
`DSContainerManager/` contains the app code. `App/` holds root composition and navigation, `Core/` contains API clients, models, extensions, and widget support, `Features/` groups TCA reducers and views by tab (`Connection`, `Dashboard`, `Containers`, `Projects`, `SystemMonitor`), and `SharedUI/` stores reusable SwiftUI components. Visual assets live in `Assets.xcassets/`. Project settings are in `DSContainerManager.xcodeproj/`, and Swift package pins are tracked in `DSContainerManager.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Build, Test, and Development Commands
- `open DSContainerManager.xcodeproj` opens the project in Xcode.
- `xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager -destination 'platform=iOS Simulator,name=iPhone 17' -skipMacroValidation build` builds the app for the iOS simulator. Requires Xcode 27 (iOS 26 SDK); `-skipMacroValidation` avoids the interactive TCA macro trust prompt on CLI builds. iPhone 17-series simulators only (iPhone 16 no longer exists in Xcode 27).
- `xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager -destination 'platform=iOS Simulator,name=iPhone 17' -skipMacroValidation test` runs the snapshot tests.
- `xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager clean` removes build artifacts before a fresh build.

## Coding Style & Naming Conventions
Use Swift and SwiftUI with the existing TCA structure. Follow Xcode’s default formatting: 4-space indentation, one type per file, `UpperCamelCase` for types, and `lowerCamelCase` for properties, methods, and enum cases. Keep feature files paired as `FeatureNameFeature.swift` and `FeatureNameView.swift`. Reducers in this repo use `@Reducer`, `@ObservableState`, dependency injection via `@Dependency`, and explicit `CancelID` cases for cancellable effects.

## Testing Guidelines
The `DSContainerManagerTests` target runs snapshot tests via getsentry/SnapshotPreviews: `DSContainerManagerSnapshotTests` subclasses `SnapshotTest` and auto-renders every SwiftUI `#Preview` in the `DSContainerManager` module — there are no hand-written `XCTestCase` methods, so add coverage by adding a `#Preview` to a view. The pass/fail signal is primarily that every preview renders without crashing. For logic-heavy changes, also manually smoke-test connection setup, dashboard refresh, and container/project actions.

## Commit & Pull Request Guidelines
Recent commits use short, imperative subjects such as `Sort containers and projects by name` and `Restore saved auth session on launch`. Keep commits focused on one behavioral change. After making changes, first summarize the touched files and validation result, then ask the user to accept the change set. Commit only after explicit approval. If the user accepts without providing a message, use a short English subject like `Remove manual 2FA toggle`. Pull requests should describe the user-facing impact, note any Synology API or auth changes, link related issues, and include screenshots for UI updates made in SwiftUI views.

## Architecture Notes
This app is TCA-first. `AppFeature` coordinates connection state and fans `baseURL` plus `authSession` into child features. If you add a new polling or in-flight effect, register and cancel it consistently so disconnects fully stop background work.
