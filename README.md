# pogetit

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local Firebase emulators

Start Auth, Firestore, and Functions emulators from the repository root:

```powershell
firebase emulators:start --only auth,firestore,functions --project demo-pogetit
```

Run the Flutter app against them with
`--dart-define=USE_FIREBASE_EMULATORS=true`. The default emulator host is
`10.0.2.2` for an Android emulator; use
`--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1` for desktop or web clients.
Emulator routing is disabled unless the development define is enabled.
