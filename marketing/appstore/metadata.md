# App Store Connect Metadata

Everything to paste into App Store Connect when creating the app record.

## App Information

| Field | Value |
| --- | --- |
| Name | DSContainerManager |
| Subtitle (30 chars max) | Docker containers on your NAS |
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

DSContainerManager is a native iOS control panel for Synology Container
Manager. Connect to your NAS over the DSM WebAPI and manage your entire Docker
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

## Notes / risks

- The name and copy mention "Synology" and "Docker" (third-party trademarks).
  The description includes an explicit non-affiliation disclaimer, which is
  the accepted practice for companion apps. If review flags Guideline 5.2.1,
  fallback subtitle: "Containers on your home NAS".
- `docs/privacy.html` must be pushed to GitHub (Pages serves from `docs/`)
  **before** submitting, so the Privacy Policy URL resolves.
