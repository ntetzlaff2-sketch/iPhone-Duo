# Shipping Snaptrap to TestFlight

GitHub Actions builds, signs and uploads the app on a GitHub-hosted Mac, so you don't need a Mac yourself. You only need a web browser and your iPhone Duo.

```
push to GitHub ──► "Compile (simulator)"         every push, no Apple account needed
Run workflow   ──► "Upload to TestFlight"        archive → sign → upload → TestFlight app
```

## One-time setup (about 20 minutes)

### 1. Apple Developer Program

Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/) ($99/year). TestFlight requires it. Approval for an individual is usually quick, but can take up to 48 hours.

Find your **Team ID**: [developer.apple.com/account](https://developer.apple.com/account) → Membership details → Team ID (10 characters, like `A1B2C3D4E5`).

### 2. Register the app

1. Pick a bundle ID you own, for example `com.yourname.snaptrap`. (The project's `com.example.Snaptrap` is a placeholder; the workflow overrides it.)
2. [Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → App IDs → App. Enter the bundle ID and the description "Snaptrap". No capabilities needed.
3. [App Store Connect → Apps](https://appstoreconnect.apple.com/apps) → **+** → New App:
   - Platform: iOS
   - Name: "Snaptrap" (must be unique on the App Store; add a suffix if it's taken)
   - Primary language: English
   - Bundle ID: the one from step 2
   - SKU: anything, e.g. `snaptrap`

### 3. Create an App Store Connect API key

[App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) → Team Keys → **+**.

- Name: `GitHub Actions`
- Access: **Admin**. Xcode's cloud signing needs Admin to create the distribution certificate and provisioning profile for you.

Note the **Issuer ID** (top of the page) and the **Key ID**, then **Download** the `.p8` file. Apple only lets you download it once.

### 4. Add the secrets to GitHub

In this repository: **Settings → Secrets and variables → Actions**.

**Secrets** tab → New repository secret:

| Name | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your Team ID |
| `APP_STORE_CONNECT_KEY_ID` | The Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | The entire contents of the `.p8` file, including the `-----BEGIN PRIVATE KEY-----` lines |

**Variables** tab → New repository variable:

| Name | Value |
| --- | --- |
| `BUNDLE_ID` | Your bundle ID, e.g. `com.yourname.snaptrap` |

Never paste the `.p8` contents anywhere else, including chats.

### 5. Set up testers

App Store Connect → your app → **TestFlight** → Internal Testing → **+** to create a group (e.g. "Me"), then add yourself. Turn on **automatic distribution** so every new build reaches the group without extra clicks.

On the iPhone Duo, install [TestFlight](https://apps.apple.com/app/testflight/id899247664) and sign in with the same Apple Account.

## Shipping a build

- **From the web:** Actions → **Build & TestFlight** → **Run workflow** → choose the branch → Run.
- **From git:** push a tag, e.g. `git tag v1.0.1 && git push origin v1.0.1`.

The run takes about 10 minutes. Apple then processes the build, which usually takes 5–30 minutes, and TestFlight notifies you when it's ready to install.

Each build number is the workflow run number + 100, so they always go up. To change the version shown to testers (1.0, 1.1, …), edit `MARKETING_VERSION` in `Snaptrap/Snaptrap.xcodeproj/project.xcproj`.

## Troubleshooting

| Error | Fix |
| --- | --- |
| `APPLE_TEAM_ID is not set` (or another name) | That secret or variable is missing or misspelled (step 4). |
| `needs the iOS 27.1 SDK` | GitHub's runner doesn't have Xcode 27.1 yet. Re-run later, or use a self-hosted Mac runner. |
| `No profiles for '…' were found` / `Cloud signing permission error` | The API key must have **Admin** access (step 3), and the bundle ID must match the one registered in step 2. |
| `No suitable application records were found` | Create the app in App Store Connect (step 2.3) with exactly the same bundle ID. |
| `The bundle version must be higher than the previously uploaded version` | Run the workflow again; the run number goes up each time. |
| Build is stuck in "Missing Compliance" | It shouldn't be: the app declares `ITSAppUsesNonExemptEncryption = NO`. If it happens, answer "None of the algorithms mentioned above" in App Store Connect. |

macOS runner minutes count against your GitHub plan at 10× the Linux rate on private repositories. A simulator compile takes about 3–5 minutes, and a TestFlight run takes about 10.
