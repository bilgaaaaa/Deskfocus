# Deskfocus

A macOS menu bar app and desktop widget, and an iPhone app made for **iPhone Duo**, that put **today's tasks and a focus timer in one place**.

- Today's list merges **iCloud Calendar, iCloud Reminders, Google Calendar and Google Tasks**; each calendar or list can be switched on or off in Settings.
- Shown as a **glass panel on the desktop** (Liquid Glass on macOS 26), as a WidgetKit widget, and in the menu bar; the panel and the widget share the same view.
- Browse **any day** with the ‹ › arrows, or switch the desktop panel to the wider **week view** with seven columns.
- Press ▶ on any task, on any day, to start a focus timer for it.
- While the timer runs, the apps you chose are **hidden** or, in strict mode, **quit** (and quit again if you open them, then reopened when the session ends). An optional macOS Focus mode silences notifications.
- Apple's Screen Time API (FamilyControls) only works on iOS and iPadOS, so blocking on the Mac is done by hiding or quitting apps.
- When the time is up you get a notification; press **Done** and the task is completed in Reminders or Google Tasks.

Requirements: macOS 14 Sonoma or later, iOS 17 or later, Xcode 16 or later.

## iPhone and iPhone Duo

The iPhone app has the same list, timer, widget and colors as the Mac, laid out for the space it gets:

- **Closed** (any iPhone, the closed iPhone Duo): one page that shows the day like the Mac widget and opens to the week from the bar.
- **Open** (the open iPhone Duo, iPad): the day and the week as two facing pages. The spread splits at the middle of the window, which on the open iPhone Duo is the fold, so the gap between the pages sits on the crease and nothing you tap lands on it. Held so it is taller than wide, the pages stack instead.
- Folding and unfolding only change the layout: the day you are on, the running session and the list stay as they are.
- The bar's buttons are system toolbar items with titles, so iPhone Duo can move them to its side strip.
- A running session is a **Live Activity** on the Lock Screen and in the Dynamic Island, with Pause, Resume, +5 min and Done.
- The Home Screen widget is the Mac widget (medium and large).
- "Time is up" is scheduled when a session starts, so it arrives on time even while iOS has the app suspended.
- No app blocking on iPhone yet: Apple's Screen Time API needs the Family Controls entitlement, which Apple has to approve before a build can go to TestFlight or the App Store.

## Project layout

| Folder | Contents |
|---|---|
| `Shared/` | Code compiled into every target: models, the shared state file, `FocusController`, App Intents, shared views |
| `Deskfocus/` | The menu bar app: task sources, Google sign-in, focus coordinator, distraction guard, views. `AppModel`, the task sources, Google sign-in and the task buttons are compiled into the iPhone app too |
| `DeskfocusWidget/` | The combined widget, used by the Mac and iPhone widget extensions |
| `DeskfocusiOS/` | The iPhone and iPad app: day and week pages, the two-page spread, Settings, and its own `FocusCoordinator` (alert and Live Activity) |
| `DeskfocusiOSWidget/` | The focus timer's Live Activity, next to the shared widget |
| `Config/` | Build settings; your personal values go in `Secrets.xcconfig` |
| `Design/` | `AppIcon.svg`, `AppIcon-iOS.svg` and `MenuBarIcon.svg`, the sources of the app icons |
| `project.yml` | XcodeGen spec that generates `Deskfocus.xcodeproj` |

### How the pieces talk

```
Widget button ──► App Intent ──► FocusController ──► shared JSON (App Group)
                                        │
                                        └─► Darwin notification ──► App: FocusCoordinator
                                                                     ├─ DistractionGuard (hide apps, Focus Shortcut)
                                                                     ├─ end timer + "time is up" notification
                                                                     └─ TaskRepository (complete in Reminders / Google Tasks)
```

The widget extension is sandboxed and cannot hide other apps or call Google, so every widget action only updates the shared state. The app, which runs at login, reacts to it.

On iPhone the same intents are Live Activity intents, so iOS runs them in the app's process, waking it in the background if needed. Before a button's intent returns, the app schedules or withdraws the "time is up" alert and starts, updates or ends the Live Activity.

## Setup

### 1. Tools

```bash
brew install xcodegen
```

### 2. Your settings

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Fill in:

- `DESKFOCUS_TEAM_ID`: your Apple Developer Team ID (Xcode › Settings › Accounts, or developer.apple.com › Membership). It is needed so the app and the widget share data through the App Group. On iPhone the group is `group.com.bilgaaaaa.deskfocus`; with automatic signing Xcode registers it on the first build to a device.
- `GOOGLE_CLIENT_ID`: see step 3. You can leave it empty at first; iCloud works without it.

### 3. Google Calendar and Tasks (optional)

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create a project, for example "Deskfocus".
2. **APIs & Services › Library**: enable **Google Calendar API** and **Google Tasks API**.
3. **APIs & Services › OAuth consent screen**: choose **External**, fill in the app name and your email, and add these scopes: `email`, `.../auth/calendar.readonly`, `.../auth/tasks`. While the app is in **Testing**, add your own Google account under **Test users**.
4. **APIs & Services › Credentials › Create credentials › OAuth client ID**:
   - Application type: **iOS** (Google uses this type for native Apple apps, including macOS).
   - Bundle ID: `com.bilgaaaaa.deskfocus`
5. Copy the client ID (`….apps.googleusercontent.com`) into `GOOGLE_CLIENT_ID`.

No client secret is needed: sign-in uses PKCE, and tokens are stored in your Keychain. The iPhone app has the same bundle ID, so the same client ID works there too.

> Before publishing to other people, Google requires an app verification review because the Calendar scope is "sensitive". Testing mode works for up to 100 test users.

### 4. Build and run

```bash
xcodegen generate
open Deskfocus.xcodeproj
```

Select the **Deskfocus** scheme and run. The app lives in the menu bar (checklist icon). Run `xcodegen generate` again whenever you add or remove files.

For the iPhone, select the **DeskfocusiOS** scheme and an iPhone, an iPad or a simulator. With Xcode 27.1 or later, the iPhone Duo simulator can open, close and fold the device to try both layouts.

### 5. First launch

A welcome guide opens on the first launch and walks through the steps below. Open it again from Settings › **General** › **Welcome guide**.

1. Settings › **Calendars**: allow Calendar and Reminders, connect Google, and switch off any calendar or list you don't want to see.
2. **Focus** tab: pick the apps to hide during focus and set the timer length.
3. **General** tab: turn on **Open Deskfocus at login**, so widget buttons work even after a restart.
4. Add the widget: right-click the desktop › **Edit Widgets** › search "Deskfocus" › choose medium or large.

Settings open from the ⚙︎ on the desktop widget, from the menu bar icon, or by opening Deskfocus again from Finder or Spotlight. Drag the desktop widget anywhere to move it; right-click it › **Reset Position** brings it back to the top-left corner.

On iPhone:

1. Tap **Calendars** and **Reminders** on the first card to allow access. Settings (gear in the bar) has the same buttons, Google, and the colors.
2. Allow notifications when asked, so "time is up" reaches you while the phone is locked.
3. Add the widget: touch and hold the Home Screen › **Edit** › **Add Widget** › Deskfocus.

### 6. Silence notifications with a Focus mode (optional)

macOS does not let apps block other apps' notifications directly, so Deskfocus switches a Focus mode for you:

1. **System Settings › Focus › Add Focus › Custom**, name it **Deskfocus**, and choose which people and apps may still notify you.
2. In the **Shortcuts** app create two shortcuts:
   - **Deskfocus On**: action *Set Focus* › Deskfocus › **On** › *Until Turned Off*.
   - **Deskfocus Off**: action *Set Focus* › Deskfocus › **Off**.
3. In Deskfocus Settings › **Focus**, enter `Deskfocus On` and `Deskfocus Off`.

The Focus mode turns on when a session starts or resumes, and off when it is paused, stopped, completed or the time is up.

## Share Deskfocus as a download

Needs the paid Apple Developer Program. The result is a signed, notarized `Deskfocus-<version>.dmg` that opens normally on any Mac with macOS 14 or later.

### One-time setup

1. Set `DESKFOCUS_TEAM_ID` in `Config/Secrets.xcconfig` to your **paid** team ID (developer.apple.com › Account › Membership details). It differs from the free Personal Team ID.
2. Xcode › Settings › Accounts › your team › **Manage Certificates…** › **+** › **Developer ID Application**.
3. Create an app-specific password at [account.apple.com](https://account.apple.com) › Sign-In and Security › App-Specific Passwords, then store it for the notary tool:
   ```bash
   xcrun notarytool store-credentials "deskfocus-notary" --apple-id YOUR_APPLE_ID_EMAIL --team-id YOUR_TEAM_ID
   ```
   Paste the app-specific password when asked. It is saved in your Keychain, never in the repo.

### Each release

1. Raise `MARKETING_VERSION` in `project.yml` (for example `0.2.0`).
2. Run:
   ```bash
   ./Scripts/release.sh
   ```
3. Send `build/Deskfocus-<version>.dmg`. The other person opens it and drags Deskfocus into Applications.

## Share the iPhone app with TestFlight

Testers install the iPhone app from Apple's TestFlight app and get each new build automatically. No cable needed, including for yourself.

### One-time setup

1. In Xcode › Settings › Accounts, sign in with the Apple ID of your paid team (the same one used for the Mac release).
2. In [App Store Connect](https://appstoreconnect.apple.com) › **Business**, accept the latest agreements.
3. App Store Connect › **Apps** › **+** › **New App**: platform **iOS**, name **Deskfocus**, bundle ID `com.bilgaaaaa.deskfocus`, any SKU (for example `deskfocus`). The Mac app shares this bundle ID, so the same record can later hold the Mac version too.

### Each build

1. Run:
   ```bash
   ./Scripts/testflight.sh
   ```
   It archives the **DeskfocusiOS** scheme, signs it for the App Store and uploads it. The build number is the current UTC time, so every upload is accepted.
2. After 5-15 minutes of processing, the build appears in App Store Connect › your app › **TestFlight**.
3. Add testers:
   - **Internal testing:** people on your team in App Store Connect › Users and Access, up to 100. Builds are available right away.
   - **External testing:** anyone, by email or a public link, up to 10,000. The first build of each version goes through a short Beta App Review.
4. Testers install **TestFlight** from the App Store, open the invite, and tap **Install**.

### Running from Xcode instead

The first time, connect the iPhone to the Mac with a cable, tap **Trust**, and turn on Settings › Privacy & Security › **Developer Mode**. Then tick **Connect via network** in Xcode › Window › Devices and Simulators; from then on Xcode installs over Wi-Fi when both are on the same network.

## Logs

Every module logs with `os.Logger` under the subsystem `com.bilgaaaaa.deskfocus` (categories: `store`, `sync`, `google`, `focus`, `distraction`, `widget`, `app`). In Console.app, filter by `subsystem:com.bilgaaaaa.deskfocus`.

## Notes

- Calendar events can't be "completed" in Calendar, so **Done** on an event only hides it for today. Done on a reminder or Google task completes it in its source; if that fails (offline), it retries on the next sync.
- If your Google account is also added in System Settings › Internet Accounts, the same event arrives twice; Deskfocus removes the duplicate by title and start time.
- Sync runs at launch, every 5 minutes, on wake, at midnight and whenever the macOS calendar database changes. On iPhone it also runs whenever the app comes to the front, and when you pull a page down.
