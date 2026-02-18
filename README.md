# running_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Setup

Firebase configuration files are **not included** in this repository for security reasons. To set up Firebase after cloning:

1. Install the FlutterFire CLI if you haven't already:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Make sure you have access to the Firebase project (`running-app-dee02`), then run:
   ```bash
   flutterfire configure --project=running-app-dee02
   ```

This will auto-generate:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
