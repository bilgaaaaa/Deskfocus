# Deskfocus

A macOS menu bar app and desktop widget that puts **today's tasks and a focus timer in one place**.

- Today's list merges **iCloud Calendar, iCloud Reminders, Google Calendar and Google Tasks**; each calendar or list can be switched on or off in Settings.
- Shown as a **glass panel on the desktop** (Liquid Glass on macOS 26), as a WidgetKit widget, and in the menu bar; the panel and the widget share the same view.
- Browse **any day** with the ‹ › arrows, or switch the desktop panel to the wider **week view** with seven columns.
- Press ▶ on any task, on any day, to start a focus timer for it.
- While the timer runs, the apps you chose are **hidden** or, in strict mode, **quit** (and quit again if you open them, then reopened when the session ends). An optional macOS Focus mode silences notifications.
- Apple's Screen Time API (FamilyControls) only works on iOS and iPadOS, so blocking on the Mac is done by hiding or quitting apps.
- When the time is up you get a notification; press **Done** and the task is completed in Reminders or Google Tasks.

Requirements: macOS 14 Sonoma or later, Xcode 16 or later.

## Project layout

| Folder | Contents |
|---|---|
| `Shared/` | Code compiled into both targets: models, the shared state file, `FocusController`, App Intents |
| `Deskfocus/` | The menu bar app: task sources, Google sign-in, focus coordinator, distraction guard, views |
| `DeskfocusWidget/` | The combined desktop widget |
| `Config/` | Build settings; your personal values go in `Secrets.xcconfig` |
| `Design/` | `AppIcon.svg` and `MenuBarIcon.svg`, the sources of the icons in `Deskfocus/Assets.xcassets` |
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

- `DESKFOCUS_TEAM_ID`: your Apple Developer Team ID (Xcode › Settings › Accounts, or developer.apple.com › Membership). It is needed so the app and the widget share data through the App Group.
- `GOOGLE_CLIENT_ID`: see step 3. You can leave it empty at first; iCloud works without it.

### 3. Google Calendar and Tasks (optional)

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create a project, for example "Deskfocus".
2. **APIs & Services › Library**: enable **Google Calendar API** and **Google Tasks API**.
3. **APIs & Services › OAuth consent screen**: choose **External**, fill in the app name and your email, and add these scopes: `email`, `.../auth/calendar.readonly`, `.../auth/tasks`. While the app is in **Testing**, add your own Google account under **Test users**.
4. **APIs & Services › Credentials › Create credentials › OAuth client ID**:
   - Application type: **iOS** (Google uses this type for native Apple apps, including macOS).
   - Bundle ID: `com.bilgaaaaa.deskfocus`
5. Copy the client ID (`….apps.googleusercontent.com`) into `GOOGLE_CLIENT_ID`.

No client secret is needed: sign-in uses PKCE, and tokens are stored in your Keychain.

> Before publishing to other people, Google requires an app verification review because the Calendar scope is "sensitive". Testing mode works for up to 100 test users.

### 4. Build and run

```bash
xcodegen generate
open Deskfocus.xcodeproj
```

Select the **Deskfocus** scheme and run. The app lives in the menu bar (checklist icon). Run `xcodegen generate` again whenever you add or remove files.

### 5. First launch

A welcome guide opens on the first launch and walks through the steps below. Open it again from Settings › **General** › **Welcome guide**.

1. Settings › **Calendars**: allow Calendar and Reminders, connect Google, and switch off any calendar or list you don't want to see.
2. **Focus** tab: pick the apps to hide during focus and set the timer length.
3. **General** tab: turn on **Open Deskfocus at login**, so widget buttons work even after a restart.
4. Add the widget: right-click the desktop › **Edit Widgets** › search "Deskfocus" › choose medium or large.

Settings open from the ⚙︎ on the desktop widget, from the menu bar icon, or by opening Deskfocus again from Finder or Spotlight. Drag the desktop widget anywhere to move it; right-click it › **Reset Position** brings it back to the top-left corner.

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

## Logs

Every module logs with `os.Logger` under the subsystem `com.bilgaaaaa.deskfocus` (categories: `store`, `sync`, `google`, `focus`, `distraction`, `widget`, `app`). In Console.app, filter by `subsystem:com.bilgaaaaa.deskfocus`.

## Notes

- Calendar events can't be "completed" in Calendar, so **Done** on an event only hides it for today. Done on a reminder or Google task completes it in its source; if that fails (offline), it retries on the next sync.
- If your Google account is also added in System Settings › Internet Accounts, the same event arrives twice; Deskfocus removes the duplicate by title and start time.
- Sync runs at launch, every 5 minutes, on wake, at midnight and whenever the macOS calendar database changes.
