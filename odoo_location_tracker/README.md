# Odoo Location Tracker — Flutter App

A native Flutter app that provides **real background GPS tracking** for Odoo employees.  
Works when the screen is locked, app is minimized, or the phone is in your pocket.

---

## Features

- ✅ Background location tracking (screen off, app minimized)
- ✅ Auto-starts on phone reboot
- ✅ Persistent foreground notification while tracking
- ✅ Pings every 30 seconds or every 5 meters moved
- ✅ Login with your Odoo URL + database + credentials
- ✅ Works on Android (iOS support included but requires Apple Developer account to distribute)
- ✅ Connects directly to your existing Odoo module endpoints

---

## Project Structure

```
lib/
├── main.dart                    # App entry point + splash screen
├── screens/
│   ├── login_screen.dart        # Login with Odoo credentials
│   └── home_screen.dart         # Tracking status + start/stop
└── services/
    ├── odoo_service.dart        # Odoo JSON-RPC auth + ping
    └── location_service.dart    # Background GPS service
```

---

## Requirements

- Flutter 3.x SDK → https://flutter.dev/docs/get-started/install
- Android Studio or Xcode (for building)
- An Odoo instance with the **employee_live_location_tracking** module installed

---

## Odoo Module Endpoints Used

| Endpoint | Purpose |
|---|---|
| `POST /web/session/authenticate` | Login, get session cookie |
| `POST /web/location/ping` | Send GPS coordinates |
| `POST /web/location/offline` | Mark employee offline on logout |

---

## Build Instructions

### 1. Clone and install dependencies

```bash
git clone https://github.com/yourname/odoo_location_tracker.git
cd odoo_location_tracker
flutter pub get
```

### 2. Build Android APK

```bash
flutter build apk --release
```

APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### 3. Install on device

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or transfer the APK file directly to your Android phone and open it.

---

## Android Permissions

The app requires these permissions (already in `AndroidManifest.xml`):

| Permission | Why |
|---|---|
| `ACCESS_FINE_LOCATION` | GPS coordinates |
| `ACCESS_BACKGROUND_LOCATION` | Track when screen is off |
| `FOREGROUND_SERVICE` | Required by Android for background tasks |
| `RECEIVE_BOOT_COMPLETED` | Auto-restart after phone reboot |
| `WAKE_LOCK` | Keep CPU active during tracking |
| `INTERNET` | Send pings to Odoo |

> **Note:** Android 10+ will ask for "Allow all the time" location permission separately. Users must grant this for background tracking to work.

---

## iOS Notes

Background location on iOS requires:
1. Apple Developer account ($99/year)
2. Add `NSLocationAlwaysAndWhenInUseUsageDescription` to `Info.plist`
3. Enable **Background Modes → Location updates** in Xcode capabilities
4. Build and distribute via TestFlight or App Store

---

## How It Works

```
Employee opens app → logs in with Odoo credentials
         ↓
App authenticates via /web/session/authenticate
         ↓
Background service starts (works screen-off, app minimized)
         ↓
Every 30 sec or 5 meters → get GPS → POST to /web/location/ping
         ↓
Admin sees live location on Odoo map dashboard
```

---

## License

MIT — free to use and modify.
