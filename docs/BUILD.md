# Build instructions

## Tool versions used

- Flutter stable 3.47.7, Dart 3.13.5
- Android SDK platform 36 and build-tools 36.0.0
- Android NDK 28.2.13676358
- OpenJDK 21.0.11
- Xcode: unavailable; only Command Line Tools are installed
- CocoaPods 1.17.0 is installed. Flutter's Swift Package Manager integration is
  enabled by default on supported Xcode installations, but it is not active in
  this environment because full Xcode is absent. Rerun `flutter pub get` after
  installing Xcode and verify which dependency manager Flutter selects.

The Flutter SDK used in this workspace is at
`/Users/deepesh.agrawal/development/flutter`. Android SDK root is
`/opt/homebrew/share/android-commandlinetools`.

## Android

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Install on a connected device or running emulator:

```bash
flutter devices
flutter install
```

The app requires Android API 24 or later because the selected camera plugin
requires that minimum. The native Astronomy Engine library is compiled by the
Flutter native-assets hook with the Android NDK. Installable APKs are written
to `build/app/outputs/flutter-apk/app-debug.apk` and
`build/app/outputs/flutter-apk/app-release.apk`.

The main app manifest contains location and camera permissions and no network
permission. Flutter's debug and profile manifests add `INTERNET` for VM-service
debugging. The release APK was inspected with `aapt dump permissions`; it has
no `INTERNET`, `ACCESS_NETWORK_STATE`, `RECORD_AUDIO`, or storage permission.
It includes coarse/fine location, camera, and Android's signature-level
dynamic-receiver permission. Its core application flow was launched on the
API 36 emulator with Wi-Fi and mobile data disabled.

Release signing is not configured. `android/app/build.gradle.kts` retains the
Flutter template's debug signing configuration for local release runs; replace
it with an owner-managed signing configuration before publishing. No signing
keys are included in this project.

The locally built release APK is optimized but is not a store-signed release.
Before publication, configure owner-managed signing, build and verify an AAB,
and complete store-policy/privacy review.

## iOS

The iOS deployment target is 15.0. Camera and location usage descriptions are
in `ios/Runner/Info.plist`; sensor channels are in `ios/Runner/AppDelegate.swift`.
The generated Xcode project supports Flutter's Swift Package Manager plugin
integration. Flutter only enables it when a compatible full Xcode installation
is available. CocoaPods 1.17.0 is installed as a fallback. On this machine:

```bash
flutter doctor -v
flutter pub get
flutter build ios --no-codesign
```

The current environment does not contain `/Applications/Xcode.app` or the iOS
SDKs. `flutter build ios --no-codesign` was attempted but Flutter could not
resolve an iOS build target because `xcodebuild` is unavailable; only Swift
syntax parsing of `AppDelegate.swift` passed. No iOS compilation or simulator
validation is claimed. Once Xcode is installed, run `flutter pub get` again,
then build and test. Distribution signing and App Store packaging require the
owner's Apple developer configuration.

## Flutter SDK on this workspace

Flutter's `bin` directory is now added to `~/.zprofile`. Open a new terminal
session to pick it up. The installed path can also be used explicitly:

```bash
/Users/deepesh.agrawal/development/flutter/bin/flutter doctor -v
/Users/deepesh.agrawal/development/flutter/bin/flutter build apk --debug
```

The app has no Android emulator definition committed to the repository. The
system image is optional for builds; physical-device checks are still needed
for GNSS, compass, motion, and camera alignment.
