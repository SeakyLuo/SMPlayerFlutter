# Simple Melody Player Flutter

Flutter migration workspace for Simple Melody Player. This project starts as a cross-platform shell only: no product UI has been ported yet.

## Targets

- Windows and macOS desktop app for local library management, local playback, and the built-in personal connection service.
- Android and iOS app for pairing with a desktop device and directly streaming music from it.
- Optional web target only if a browser remote becomes useful later.

## Baseline Dependencies

- App structure: `flutter_riverpod`, `go_router`.
- Local storage: `drift`, `sqlite3_flutter_libs`, `path`, `path_provider`.
- Desktop personal service: `shelf`, `shelf_router`, Dart `dart:io` sockets.
- Pairing and identity: `qr_flutter`, `mobile_scanner`, `crypto`, `uuid`, `device_info_plus`, `package_info_plus`.
- Playback: `just_audio`, `audio_service`.
- Connectivity and files: `connectivity_plus`, `file_picker`, `http`, `url_launcher`.
- Desktop integration: `window_manager`, `tray_manager`.

## Architecture Direction

Keep the music library, database, pairing, connection diagnostics, and streaming protocol independent from Flutter screens. Desktop and mobile should call the same core services where possible.

Planned source layout:

- `lib/src/app`: app bootstrap, routing, top-level providers.
- `lib/src/library`: music scan, metadata, artwork, lyrics, playlists.
- `lib/src/playback`: local playback and remote stream playback.
- `lib/src/remote`: pairing, authorization, HTTP APIs, streaming, connectivity checks.
- `lib/src/storage`: Drift database and local file paths.
- `lib/src/platform`: desktop/mobile integration such as tray, windows, background audio, file pickers, and desktop lyrics.
- `lib/src/shared`: DTOs, constants, formatting, protocol models.

## Desktop Lyrics

Flutter can support desktop lyrics on desktop platforms, but it is not a built-in one-line feature. The likely implementation is a separate always-on-top transparent window using `window_manager`, plus platform-specific work where needed for click-through, taskbar behavior, screen placement, and global hotkeys.

Mobile platforms should not reuse the desktop lyrics model directly.

## Remote Playback Scope

This app will not rely on an official cloud service. A desktop device can run its own local connection service. A paired mobile device can connect and stream from it when the desktop device is reachable.

Out-of-home access can be attempted with reachable IPv6, UPnP/NAT-PMP, port forwarding, DDNS, or user-managed VPN tools. Without a reachable route, the mobile app should show a clear connection failure instead of implying cloud availability.

## Useful Commands

```powershell
flutter pub get
flutter analyze
flutter run -d windows
```
