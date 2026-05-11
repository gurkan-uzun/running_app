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

  -----

### 🚀 Onboarding Guide: First-Time Setup

To guarantee we all have the exact same build environment and zero "it works on my machine" bugs, this project strictly uses **FVM** (Flutter Version Management) and **Ruby Bundler** (for iOS Pods).

#### **Phase 1: One-Time Global Setup (If you don't have these already)**

**1. Install FVM & Add it to your PATH:**
Run these three commands one by one to install FVM and ensure your Mac's terminal knows where to find it:

```bash
dart pub global activate fvm
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc

```

*(Alternatively, if you use Homebrew, you can just run: `brew tap leoafarias/fvm && brew install fvm`)*

**2. Install Ruby 3.3.0 (Mac/iOS only):**
This project locks Ruby to version 3.3.0 to prevent CocoaPods crashes. We recommend using `rbenv` to install it:

```bash
rbenv install 3.3.0

```

#### **Phase 2: Project Setup (Run this after cloning the repo)**

Open your terminal, navigate to the cloned project folder, and run these commands in order:

```bash

# 1. Download the project's exact Flutter SDK (3.41.6)
fvm install

# 2. Download the iOS engine artifacts (Crucial to prevent Pod errors)
fvm flutter precache --ios

# 3. Get the exact Dart packages
fvm flutter pub get

# 4. Setup iOS dependencies (Mac/iOS only)
cd ios
gem install bundler  # Installs the package manager (if you don't have it)
bundle install       # Installs the exact CocoaPods version for this project
bundle exec pod install # Installs the iOS SDKs
cd ..

```

---

### ⚠️ The Golden Rules for this Project

From now on, you **must not** use the standard `flutter` or `pod` commands. If you do, you will use your machine's global versions and break the lockfiles.

* **❌ NEVER DO:** `flutter run`
* **✅ ALWAYS DO:** `fvm flutter run`
* **❌ NEVER DO:** `flutter pub get`
* **✅ ALWAYS DO:** `fvm flutter pub get`
* **❌ NEVER DO:** `pod install` (inside the ios folder)
* **✅ ALWAYS DO:** `bundle exec pod install` (inside the ios folder)

**IDE Setup (VS Code):**
When you open this project in VS Code, the `.vscode/settings.json` file will automatically point your editor to the FVM version. You will see a prompt in the bottom right corner asking to change the workspace SDK. Click **Accept**.


That is a brilliant addition. You are completely right—since your teammates might not have their Dart pub-cache in their system PATH, they will hit the exact same `command not found: fvm` error you did.

We can make this foolproof for them by giving them a single command that automatically adds it to their `.zshrc` file (the default for all modern Macs).

Here is the fully updated, copy-pasteable guide for your team:

---

### 🚀 Onboarding Guide: First-Time Setup

To guarantee we all have the exact same build environment and zero "it works on my machine" bugs, this project strictly uses **FVM** (Flutter Version Management) and **Ruby Bundler** (for iOS Pods).

#### **Phase 1: One-Time Global Setup (If you don't have these already)**

**1. Install FVM & Add it to your PATH:**
Run these three commands one by one to install FVM and ensure your Mac's terminal knows where to find it:

```bash
dart pub global activate fvm
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc

```

*(Alternatively, if you use Homebrew, you can just run: `brew tap leoafarias/fvm && brew install fvm`)*

**2. Install Ruby 3.3.0 (Mac/iOS only):**
This project locks Ruby to version 3.3.0 to prevent CocoaPods crashes. We recommend using `rbenv` to install it:

```bash
rbenv install 3.3.0

```

#### **Phase 2: Project Setup (Run this after cloning the repo)**

Open your terminal, navigate to the cloned project folder, and run these commands in order:

```bash
# 1. Download the project's exact Flutter SDK (3.41.6)
fvm install

# 2. Get the exact Dart packages
fvm flutter pub get

# 3. Setup iOS dependencies (Mac/iOS only)
cd ios
gem install bundler  # Installs the package manager
bundle install       # Installs the exact CocoaPods version for this project
bundle exec pod install # Installs the iOS SDKs
cd ..

```

---

### ⚠️ The Golden Rules for this Project

From now on, you **must not** use the standard `flutter` or `pod` commands. If you do, you will use your machine's global versions and break the lockfiles.

* **❌ NEVER DO:** `flutter run`
* **✅ ALWAYS DO:** `fvm flutter run`
* **❌ NEVER DO:** `flutter pub get`
* **✅ ALWAYS DO:** `fvm flutter pub get`
* **❌ NEVER DO:** `pod install` (inside the ios folder)
* **✅ ALWAYS DO:** `bundle exec pod install` (inside the ios folder)

**IDE Setup (VS Code):**
When you open this project in VS Code, the `.vscode/settings.json` file will automatically point your editor to the FVM version. You will see a prompt in the bottom right corner asking to change the workspace SDK. Click **Accept**.