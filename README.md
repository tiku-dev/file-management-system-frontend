# Smart File

Smart File is a privacy-first Flutter file manager for Windows and Android.
The user chooses a folder, and the app only reads or changes that folder and
its children. The backend plans AI operations; the app executes them locally.

## Run on Windows

Start the Django REST Framework backend in `../backend_drf`:

```powershell
cd ../backend_drf
.\venv\Scripts\Activate.ps1
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Then run the app:

```powershell
flutter pub get
flutter run -d windows
```

Choose a folder in the app. The initial screen intentionally does not scan the
user profile automatically.

## Run on Android

For an Android emulator, the default backend URL is `http://10.0.2.2:8000`.
For a physical phone:

1. Find the computer's LAN IP address (or use USB with `adb reverse tcp:8000 tcp:8000`).
2. Start `backend_drf` with `python manage.py runserver 0.0.0.0:8000` and allow port 8000 through the local firewall.
3. Open Smart File → Settings and set `http://<computer-ip>:8000` (or `http://127.0.0.1:8000` over USB).
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
