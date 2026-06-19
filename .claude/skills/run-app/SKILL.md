---
name: run-app
description: Build, install, and launch the DSContainerManager iOS app on the iOS Simulator, then screenshot it to confirm it rendered. Use when asked to run, build, launch, or screenshot the app on simulator.
---

# Run DSContainerManager on the iOS Simulator

This is an Xcode project (not SPM) targeting iOS 26 SDK. It must be built with
Xcode 27 (beta). Bundle ID: `com.bystritski.DSContainerManager`.

## Prerequisites (verified working)

- Active Xcode must be **Xcode 27**, not Command Line Tools. Verify:
  ```bash
  xcode-select -p   # must print .../Xcode-beta.app/Contents/Developer
  xcodebuild -version   # Xcode 27.0
  ```
  If it points at `/Library/Developer/CommandLineTools`, the user must run
  (interactively, needs sudo password — you cannot do this):
  ```bash
  sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
  ```
- `-skipMacroValidation` is **required** on the CLI build: TCA's SPM macros
  (ComposableArchitecture / swift-case-paths / swift-dependencies / swift-perception)
  otherwise fail with "Macro ... was changed since a previous approval and must be
  enabled before it can be used". The flag is harmless. (Approving macros once in the
  Xcode GUI removes the need, but the flag still works either way.)

## Build

```bash
cd /Users/bogdan/GIT/DSContainerManager
xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build/DerivedData \
  -skipMacroValidation \
  build 2>&1 | grep -iE "error:|BUILD SUCCEEDED|BUILD FAILED"
```

The full output is huge; grep for the result line. The product lands at
`build/DerivedData/Build/Products/Debug-iphonesimulator/DSContainerManager.app`.

## Boot + install + launch

Use `iPhone 17` (any iPhone 17-series sim works; iPhone 16 does not exist in Xcode 27).

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null   # ok if already booted
xcrun simctl bootstatus "iPhone 17" -b       # waits until fully booted

xcrun simctl install booted \
  build/DerivedData/Build/Products/Debug-iphonesimulator/DSContainerManager.app
xcrun simctl launch booted com.bystritski.DSContainerManager
```

Note: opening `Simulator.app` via `open` may fail in Xcode 27 (path moved) — it is
not needed; `simctl` boots the device headlessly and screenshots work regardless.

## Drive it — confirm it rendered

A returned PID does not prove the UI came up. Screenshot and look:

```bash
xcrun simctl io booted screenshot /tmp/dscm_run.png
```

Then Read `/tmp/dscm_run.png`. Expected first screen (disconnected state):
the **Connections** list rendered by `ConnectionListView`, showing any saved NAS
profiles and a "+" button. A springboard/home screen means the app is not in the
foreground yet — relaunch and re-screenshot.

## Limits

The login flow needs a real Synology NAS reachable from the host network
(e.g. `192.168.1.70:5000`). The simulator cannot reach it unless it is on the
user's LAN, so end-to-end auth/dashboard/container actions cannot be smoke-tested
from a screenshot alone — stop at the Connections screen unless a reachable NAS exists.
