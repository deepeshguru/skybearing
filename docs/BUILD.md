# Build instructions

## Tool versions used

- Flutter stable 3.47.7, Dart 3.13.5
- Android SDK platform 36 and build-tools 36.0.0
- Android NDK 28.2.13676358
- Eclipse Temurin JDK 21.0.12.1
- Windows 11 build host

On this Windows host, Flutter is installed under
`%LOCALAPPDATA%\OfflineSkyBuild\flutter` and the Android SDK under
`%LOCALAPPDATA%\OfflineSkyBuild\android-sdk`.

## Android

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
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
API 36 emulator in the previous handoff with Wi-Fi and mobile data disabled.

Use the normal `flutter build apk --release` command after dependency changes.
It regenerates the release plugin registrant without dev-only plugins such as
`integration_test`; `--no-pub` can leave a registrant that references a plugin
which is absent from the release classpath.

The signed direct-install APK is
`artifacts/google-play/sky-atlas-offline-release.apk`, version 0.1.2 (version
code 3), with minimum API 24 and target API 36. It contains `armeabi-v7a`,
`arm64-v8a`, and `x86_64` native libraries. Android `apksigner` verifies its
v2 signature, and it passes `zipalign -c -P 16 4`. Its size is 59,441,216
bytes and its SHA-256 is
`ff91509371970b54bc92e8d909a127275b762c666a2e7f0382e6def082a6d59e`.

The APK was rebuilt from the checked-in app source on 2026-10-26 with Flutter
3.47.7, Dart 3.13.5, Android SDK 36, NDK 28.2.13676358, and JDK 21.0.12.1. It
is signed with a dedicated 4096-bit RSA key. Its signer SHA-256 fingerprint is
`b1fa3f7ca44e92012a96a5265147d061410588819827ae0125bef978f646b209`.

`android/app/build.gradle.kts` reads release signing values from
`~/.config/offline-sky/android-signing.properties` or the documented
`OFFLINE_SKY_UPLOAD_*` environment variables. The keystore and properties file
are outside this repository, under `%USERPROFILE%\.config\offline-sky` on
this Windows machine. Keep an encrypted backup of `offline-sky-upload.jks` and
use this same key for every update. An APK installed with a different signing
certificate cannot update to this release; uninstall it first.

The APK is locally signed for direct installation. The current signed Play
upload bundle is `artifacts/google-play/sky-atlas-offline-release.aab` (version
0.1.2, code 3; 58,952,799 bytes), built from the renamed source on 2026-10-26
and verified with `jarsigner`. Its application label is **Sky Atlas Offline**.
Enroll in Play App Signing and keep the existing upload keystore and passwords
backed up outside the repository for all future builds.
Review the store listing and policy materials in `docs/GOOGLE_PLAY_RELEASE.md`
and `docs/PRIVACY_POLICY.md` before submitting.

## iOS

The iOS deployment target is 15.0. Camera and location usage descriptions are
in `ios/Runner/Info.plist`; sensor channels are in `ios/Runner/AppDelegate.swift`.
Build iOS on macOS with full Xcode installed:

```bash
flutter doctor -v
flutter pub get
flutter build ios --no-codesign
```

No iOS build was performed in the current Windows session. Distribution signing
and App Store packaging require the owner's Apple developer configuration.

## Windows toolchain locations

The installed Flutter and Android SDK paths can be used explicitly:

```powershell
& "$env:LOCALAPPDATA\OfflineSkyBuild\flutter\bin\flutter.bat" doctor -v
& "$env:LOCALAPPDATA\OfflineSkyBuild\flutter\bin\flutter.bat" build apk --release
```

The app has no Android emulator definition committed to the repository. The
system image is optional for builds; physical-device checks are still needed
for GNSS, compass, motion, and camera alignment.
