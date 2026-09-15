# Smart File

Smart File is a privacy-first Flutter file manager for Windows and Android.
The user chooses a folder, and the app only reads or changes that folder and
its children. The backend plans AI operations; the app executes them locally.

## Run on Windows

Start the backend in `../backend`:

```powershell
npm run dev
```

Then run the app:

```powershell
flutter pub get
flutter run -d windows
```

Choose a folder in the app. The initial screen intentionally does not scan the
user profile automatically.

## Run on Android

For an Android emulator, the default backend URL is `http://10.0.2.2:4000`.
For a physical phone:

1. Find the computer's LAN IP address.
2. Start the backend with `HOST=0.0.0.0` and allow port 4000 through the local firewall.
3. Open Smart File → Settings and set `http://<computer-ip>:4000`.
4. Choose a folder through the Android system picker.

The app does not contain a Groq key. Sign in with the backend account, then use
the Assistant tab to send prompts. The server returns proposals; the app asks
for confirmation before applying moves, renames, or other changes.

## Current functionality

- scoped local folder browsing on Windows and Android;
- folder search, metadata, create-folder, rename, move, and delete;
- authenticated AI chat connected to `/api/mobile/plan`;
- local execution of list/search/metadata plans;
- explicit approval for AI-proposed file changes;
- activity history for local and approved AI operations;
- backend URL and account settings.

Raw file contents are not sent to the backend by the mobile planner. The app
also does not advertise unsupported server-side operations as available.
