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
flutter build apk --release   # needs android/key.properties (not in the repository)
```

## Licence

Proprietary software. © FORBIDDEN S.A.S. All rights reserved. See `LICENSE`.
