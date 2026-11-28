# Vesta Parent (vesta_app)

Guardian app of **Vesta Security**, a family digital protection service for Android.
It pairs with **Vesta Tracker**, installed on the minor's phone.

Main features: dashboard with linked devices, QR linking, location and safe zones,
SOS alerts, usage reports (PDF export and weekly summary), study mode, daily time
limits, requests from the minor, web filters with safe search, alerts and
privacy authorisations per purpose.

## Development

- Flutter 3 / Dart 3, Android (minSdk 24).
- Firebase project `vesta-opensource` (Auth, Firestore, FCM). Backend: `vesta-api`.
- UI language: Spanish and English (`lib/l10n/`). Spanish text is the key; English
  lives in `lib/l10n/en.dart`. Use `tr('…')` for every visible string.
- Legal documents: `assets/legal/` (Spanish, official) and `assets/legal/en/`
  (courtesy translation).

```bash
flutter pub get
flutter analyze
flutter test
# APK for vestasecurity.date (self-updating) and bundle for Google Play.
# Both need the signing key (vesta-build/secrets/signing, not in the repository).
flutter build apk --release --flavor web --dart-define=VESTA_API_URL=https://api.vestasecurity.date
flutter build appbundle --release --flavor play --dart-define=VESTA_API_URL=https://api.vestasecurity.date
```

## Updates

Two Android flavours with the same `applicationId` and key:

- **web**: the APK from `vestasecurity.date/downloads`. It checks
  `downloads/version.json` when it opens and every 6 h on Wi-Fi; it downloads
  the new APK, checks its SHA-256 and signing key and installs it with
  `PackageInstaller` (no tap on Android 12+ once "install unknown apps" is
  allowed; otherwise Android asks). Code: `android/app/src/web`,
  `lib/services/app_updater.dart`. Publish with
  `vesta-build/publicar-actualizacion.sh` after raising `version:` in `pubspec.yaml`.
- **play**: no self-updater and no `REQUEST_INSTALL_PACKAGES` (Play policy).
  Play installs the updates; the app asks Play for an in-app update when one
  is available (priority 4-5 in Play Console = immediate).

`flutter run` and `flutter build` use `web` by default (`default-flavor` in
`pubspec.yaml`).

## Web panel

The same app runs in the browser at `https://app.vestasecurity.date`
(publish with `vesta-build/publicar-web-padre.sh`). Differences on the web:
Google/GitHub sign-in uses Firebase's pop-up, there are no push notifications
yet, and on wide screens the app is shown as a centred column. The API allows
CORS only from the web panel's origins (`VESTA_WEB_ORIGINS`).

Build: `flutter build web --release --no-web-resources-cdn --csp
--dart-define=VESTA_API_URL=…`. The server's Content-Security-Policy
(`/etc/nginx/sites-available/vesta-app`) lists the hashes of FlutterFire's
inline scripts; update them when the `firebase_*` packages change.

## Licence

Copyright © 2026 FORBIDDEN S.A.S.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License version 3 (AGPL-3.0). See `LICENSE`.
