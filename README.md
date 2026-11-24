# practise_maps_location_flutter

A Flutter practice project for learning location features: fetching and listening to the device location, showing it on an OpenStreetMap map, and tracking it in the background with a notification.

> Work in progress. This README will be finalized later.

## Features

- Fetch / listen to the live device location with `geolocator`
- Permission and service handling, with dialogs that open app or location settings
- Live map on OpenStreetMap (`flutter_map`, no API key) with a marker, a trail line and a follow/recenter button
- Background tracking:
  - Android: foreground service with a persistent notification
  - iOS: `location` background mode with the background-location indicator
- A notification that shows live latitude and longitude, updated as you move
- Simple state class (`LocationState`) used with `setState`

## Screens

| File | Purpose |
| --- | --- |
| `lib/presentations/location_fetch_screen.dart` | Start/stop listening and show coordinates as text |
| `lib/presentations/map_screen.dart` | Live location on the map (foreground) |
| `lib/presentations/background_map_screen.dart` | Live map with background tracking and notifications (currently the home screen in `main.dart`) |

Other files:
- `lib/presentations/states/location_state.dart`: `isLoading`, `isListening`, `errorMessage`, `latitude`, `longitude`
- `lib/services/tracking_notification_service.dart`: live-coordinates notification

## Packages

- `geolocator`: location and permissions
- `permission_handler` (^12): notification and "allow all the time" permissions on Android
- `flutter_map` and `latlong2`: map UI
- `flutter_local_notifications` (^22): live-coordinates notification
- `google_maps_flutter`: present in `pubspec.yaml` but unused

## Setup

```
flutter pub get
flutter run
```

Notes:
- On Windows, plugins need symlink support, so enable Developer Mode (`start ms-settings:developers`).
- Android needs core library desugaring (already enabled in `android/app/build.gradle.kts`).
- `permission_handler` 13 and `flutter_local_notifications` 23 need `compileSdk` 37, which the current Android Gradle Plugin doesn't support, so the older majors are pinned.

## Platform configuration

**Android** (`AndroidManifest.xml`): `INTERNET`, fine/coarse/background location, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `POST_NOTIFICATIONS`.

**iOS** (`Info.plist`): `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: location`. Not tested yet because iOS builds need a Mac.

## Known limitations / to check

- Behaviour after swiping the app out of recents is untested and may stop updates.
- Some phones (Infinix, Xiaomi, Samsung, ...) kill background apps; set the app's battery usage to Unrestricted.
- The trail is kept in memory only and resets on restart.
- If the tracking notification is hidden, check the "Location tracking" channel in the app's notification settings (reinstall once if the channel was created earlier at low importance).
- Background location apps need a declaration and review on Google Play before release.
