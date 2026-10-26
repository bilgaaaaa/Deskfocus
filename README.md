# Deskfocus

A macOS menu bar app and desktop widget that puts **today's tasks and a focus timer in one place**.

- Today's list merges **iCloud Calendar, iCloud Reminders, Google Calendar and Google Tasks**.
- Press ▶ on any task (in the widget or the menu bar) to start a focus timer for it.
- While the timer runs, the apps you chose are hidden (and hidden again if you open them), and an optional macOS Focus mode silences their notifications.
- When the time is up you get a notification; press **Done** and the task is completed in Reminders or Google Tasks.

Requirements: macOS 14 Sonoma or later, Xcode 16 or later.

## Project layout

| Folder | Contents |
|---|---|
| `Shared/` | Code compiled into both targets: models, the shared state file, `FocusController`, App Intents |
| `Deskfocus/` | The menu bar app: task sources, Google sign-in, focus coordinator, distraction guard, views |
| `DeskfocusWidget/` | The combined desktop widget |
| `Config/` | Build settings; your personal values go in `Secrets.xcconfig` |
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

1. Menu bar icon › ⚙︎ › **Accounts**: allow Calendar and Reminders, and connect Google.
2. **Focus** tab: pick the apps to hide during focus and set the timer length.
3. **General** tab: turn on **Open Deskfocus at login**, so widget buttons work even after a restart.
4. Add the widget: right-click the desktop › **Edit Widgets** › search "Deskfocus" › choose medium or large.

### 6. Silence notifications with a Focus mode (optional)

macOS does not let apps block other apps' notifications directly, so Deskfocus switches a Focus mode for you:

1. **System Settings › Focus › Add Focus › Custom**, name it **Deskfocus**, and choose which people and apps may still notify you.
2. In the **Shortcuts** app create two shortcuts:
   - **Deskfocus On**: action *Set Focus* › Deskfocus › **On** › *Until Turned Off*.
   - **Deskfocus Off**: action *Set Focus* › Deskfocus › **Off**.
3. In Deskfocus Settings › **Focus**, enter `Deskfocus On` and `Deskfocus Off`.

The Focus mode turns on when a session starts or resumes, and off when it is paused, stopped, completed or the time is up.

## Logs

Every module logs with `os.Logger` under the subsystem `com.bilgaaaaa.deskfocus` (categories: `store`, `sync`, `google`, `focus`, `distraction`, `widget`, `app`). In Console.app, filter by `subsystem:com.bilgaaaaa.deskfocus`.

## Notes

- Calendar events can't be "completed" in Calendar, so **Done** on an event only hides it for today. Done on a reminder or Google task completes it in its source; if that fails (offline), it retries on the next sync.
- If your Google account is also added in System Settings › Internet Accounts, the same event arrives twice; Deskfocus removes the duplicate by title and start time.
- Sync runs at launch, every 5 minutes, on wake, at midnight and whenever the macOS calendar database changes.
