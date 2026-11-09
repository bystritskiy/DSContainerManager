# App Store Connect Metadata

Everything to paste into App Store Connect when creating the app record.

## What's New — 1.1 (4000 chars max)

Home-screen widget
• New small and medium widgets show how many containers are running, NAS CPU and memory, and your running containers at a glance.

Sign in once
• After you enter a two-factor code, DSContainer asks DSM to trust this iPhone, so later sign-ins skip the code. You can revoke it any time in DSM under Personal › Security.

Easier connections
• Touch and hold a connection to edit or delete it.
• A clear message when iOS blocks Local Network access, instead of "The Internet connection appears to be offline".

Fixes and polish
• Memory usage in System Monitor no longer counts cache as used.
• Container details show the image name instead of a digest.
• Secret-looking environment variables are hidden until you tap them.
• A shorter dashboard with your running containers and a link to the full list.
• Status dots in the container list, a visible status filter, and cleaner charts.
• Better layout on wide and foldable screens.

## App Information

| Field | Value |
| --- | --- |
| Name (30 chars max) | DSContainer Manager |
| Subtitle (30 chars max) | Syno NAS Docker manager - DSM |
| Home-screen name (`CFBundleDisplayName`) | DSContainer |
| Bundle ID | com.bystritski.DSContainerManager |
| SKU | dscontainermanager-001 |
| Primary Language | English (U.S.) |
| Primary Category | Utilities |
| Secondary Category | Developer Tools |
| Age Rating | 4+ (no objectionable content) |
| Price | Free |

## URLs

| Field | Value |
| --- | --- |
| Support URL | https://bystritskiy.github.io/DSContainerManager/ |
| Privacy Policy URL | https://bystritskiy.github.io/DSContainerManager/privacy.html |
| Marketing URL (optional) | https://bystritskiy.github.io/DSContainerManager/ |

## Promotional Text (170 chars max)

Manage Docker containers and Compose projects on your Synology NAS from your
iPhone. Start, stop, and monitor — from anywhere on your network.

## Description

DSContainer is a native iOS control panel for the Container Manager package on
your Synology NAS. Connect over the DSM WebAPI and manage your entire Docker
setup without opening a browser.

DASHBOARD AT A GLANCE
• Running, stopped, and unhealthy containers in one view
• Live CPU and memory utilization of your NAS
• Recent container activity

CONTAINERS
• Start, stop, and restart containers with one tap
• Live logs with search
• Per-container CPU and memory charts
• Detailed configuration: ports, volumes, environment

COMPOSE PROJECTS
• See every Compose project and its services
• Bring whole stacks up or down

SYSTEM MONITOR
• CPU, RAM, and volume utilization charts
• Storage overview for every volume

BUILT FOR TRUST
• Talks only to your NAS — no third-party servers, no analytics
• Credentials stored in the iOS Keychain
• Supports HTTPS and 2FA (OTP) sign-in
• Self-signed certificates supported

Try Demo Mode to explore the app with sample data — no NAS required.

Requires a Synology NAS running DSM with the Container Manager package
installed. This app is an independent project and is not affiliated with or
endorsed by Synology Inc. or Docker Inc.

## Keywords (100 chars max, comma-separated)

synology,docker,container,nas,compose,dsm,portainer,devops,homelab,server,monitor,selfhosted

*(96 chars — do not add spaces after commas)*

## App Privacy (questionnaire)

- **Data collection: "Data Not Collected"** — the app has no analytics, no
  tracking, no third-party SDKs, and no first-party servers. Credentials stay
  in the on-device Keychain; all traffic goes directly to the user's NAS.

## App Review Information

- Sign-in required: **No** (check "Sign-in required" = off; use notes below)
- Notes for review:

> This app manages Docker containers on the user's own Synology NAS on their
> local network, so a live login cannot be provided. To evaluate all
> functionality, tap "Try Demo Mode" at the bottom of the first screen — it
> loads a fully interactive session with realistic sample data (dashboard,
> containers, logs, resource charts, Compose projects, system monitor) and
> requires no network access or credentials. Disconnect from Settings to leave
> the demo.

- Contact: fill in your phone + email in App Store Connect.

## Export Compliance

`ITSAppUsesNonExemptEncryption = NO` is set in the project — the app only uses
HTTPS/ATS (exempt). App Store Connect will not ask about encryption per build.

## Screenshots

6.9" iPhone (1320×2868), already rendered in `screenshots/appstore/`:
dashboard, containers, details, logs, resources, projects, monitor.
Upload order suggestion: dashboard → containers → details → logs → resources →
projects → monitor.

## Creative assets (product page header + search results)

App Store "Creative Assets" (live in App Store Connect since 2026-10-05): a
21:9 header at the top of the product page (iOS 27+) and a 3:2 image in search
results. Rendered by `npm --prefix marketing/appstore run render:creative`
(`creative.html` + `render-creative.mjs`) into `screenshots/appstore/creative/`:

- `header-3840x1646.png` — copy inside Apple's centered 1646×661 safe area.
- `search-3840x2560.png` — copy inside the centered 2168×1030 safe area.

Upload as **PNG**: App Store Connect rejected the `.jpg` with "invalid file
extension" even though the spec lists it. No alpha channel allowed. Attached to
version 1.1 under Product Page Information → Header and Search Results.

## Build configuration (already in the project)

These live in `DSContainerManager/Info.plist`, merged with the Xcode-generated
keys (`GENERATE_INFOPLIST_FILE = YES` + `INFOPLIST_FILE`):

- `NSAppTransportSecurity` → `NSAllowsLocalNetworking = YES`. The connection
  form defaults to plain HTTP, which ATS blocks outright; this exception covers
  local addresses without the review burden of `NSAllowsArbitraryLoads`.
  HTTP to a *public* DDNS hostname is still blocked — use HTTPS there.
- `NSLocalNetworkUsageDescription`. iOS 18+ gates every local-network
  connection behind a permission prompt.
- `BGTaskSchedulerPermittedIdentifiers` +
  `UIBackgroundModes = fetch`, for `BackgroundMonitor`'s health check
  (`com.dscontainermanager.container-health-check`). Without them the task
  registration is silently rejected.

`DSContainerManager/PrivacyInfo.xcprivacy` declares no tracking, no collected
data, and the `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` for
`SharedStorage.sharedDefaults`. Missing this triggers an ITMS-91053 email from
Apple after upload.

## Upload (Xcode Organizer)

1. Archive: Xcode → Product → Destination → *Any iOS Device*, then Product →
   Archive. (CLI equivalent: `xcodebuild -scheme DSContainerManager
   -destination 'generic/platform=iOS' -archivePath build/DSContainerManager.xcarchive
   -skipMacroValidation archive`.)
2. Organizer → *Distribute App* → **App Store Connect** → *Upload*. There is
   no Apple Distribution certificate in the keychain yet — let Xcode create it
   when it offers to. Keep automatic signing on.
3. The app record must exist in App Store Connect **before** the upload
   (bundle ID `com.bystritski.DSContainerManager` is already registered).
4. After processing (~10–30 min), attach the build to the version, fill in
   the fields above, and submit.

Xcode 27.2 (27B48) is a released Xcode and is accepted by App Store Connect;
never archive with a beta (build numbers ending in a letter).

Bump `CURRENT_PROJECT_VERSION` for every re-upload — build 1 is burned once
uploaded, even if the submission is rejected.

## Notes / risks

- App Store name is **DSContainer Manager**, home-screen name is
  **DSContainer** (`CFBundleDisplayName`) — same split DSLoad Station uses.
  Avoid "Container Station": that is QNAP's product name, not Synology's.
- The name and copy mention "Synology" and "Docker" (third-party trademarks).
  The description includes an explicit non-affiliation disclaimer, which is
  the accepted practice for companion apps. If review flags Guideline 5.2.1,
  fallback subtitle: "Containers on your home NAS".
- `docs/privacy.html` is live at the Privacy Policy URL above (GitHub Pages
  serves from `docs/` on `main`) — re-check it resolves before submitting.
