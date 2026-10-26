# Implementation progress

Updated 2026-10-26. The historical test results below are from the previous
handoff; a fresh Android release build and APK validation were completed today.

## Implemented

- Flutter/Riverpod application with interactive sky map, offline discovery,
  object details, saved objects, location/time settings, 3D locator, and camera
  preview overlay.
- Astronomy Engine C v2.1.19 compiled as a native asset and called over Dart
  FFI. Catalog transforms run in a background isolate; map rendering consumes
  cached snapshots.
- Bundled 9 MB SQLite catalog with 22,220 objects, all 88 constellation
  figures, plus a separately licensed SIMBAD-derived target JSON file.
- Android rotation-vector orientation and iOS Core Motion orientation sources;
  Geolocator-based location, manual/saved fallback, and local preferences.
- Offline integration workflow covering manual location, local Jupiter search,
  real ephemeris details, and local horizon/coordinate output.
- Camera initialization race fixed after emulator permission handling exposed
  concurrent CameraX initialization. The retry-safe lifecycle now prevents
  duplicate starts.

## Previously verified results

- The prior handoff used Flutter 3.47.7, Dart 3.13.5, Android SDK 36/build-tools
  36.0.0, NDK 28.2.13676358, and OpenJDK 21.0.11 on Apple Silicon macOS.
- `flutter analyze`: passed with no issues.
- `flutter test`: 12 tests passed.
- `packages/astro_engine` `dart test -r expanded`: 14 tests passed, including
  nine Solar System bodies plus Sun vs JPL Horizons checks under the documented
  <0.1° fixture threshold. Build-hook output includes expected missing-iOS-SDK
  diagnostics on this Xcode-less host and one upstream C initializer warning.
- `python3 tooling/test_catalog.py`: 5 checks passed.
- `flutter test integration_test/offline_workflow_test.dart -d emulator-5554`:
  passed on the API 36 emulator with Wi-Fi and mobile data disabled.
- `flutter build apk --debug`: passed. The debug APK is for development and
  includes Flutter's development `INTERNET` permission.
- `flutter build apk --release`: passed. The release APK is 58.5 MB and was
  installed and launched offline on the API 36 emulator. `aapt dump permissions`
  confirmed no `INTERNET`, audio, or storage permission in the release package;
  it contains only coarse/fine location, camera, and Android's signature-level
  dynamic-receiver permission.
- `swiftc -frontend -parse ios/Runner/AppDelegate.swift`: passed syntax parsing;
  this does not substitute for an iOS build.
- Emulator workflows confirmed offline sky rendering, local Jupiter search,
  object details, time travel, favorites, locator guidance, and camera preview.
  Location was manually entered. Camera preview and sensor values are emulator
  output, not physical-device accuracy checks.

## Not verified / still required for public release

- iOS build/simulator/device testing: blocked by missing full Xcode and iOS
  SDKs. Flutter cannot activate the project's SwiftPM integration without
  compatible Xcode. CocoaPods 1.17.0 is installed; rerun `flutter pub get` after
  installing Xcode and confirm the selected dependency manager. The attempted
  build exited before compilation because `xcodebuild` is unavailable.
- Full Xcode installation was attempted through `mas`, but the App Store is not
  signed in and macOS requested administrator authorization. The Xcode App
  Store listing was opened; installation must be completed interactively by the
  machine owner.
- Physical Android/iPhone GNSS acquisition, compass quality, rotation mapping,
  battery/performance profiling, and calibrated camera-to-sky placement remain
  untested. No physical mobile device is attached.
- Performance measurements (frame rate, CPU, memory, startup, battery) were
  not collected.
- The production signing key is stored outside the repository under
  `%USERPROFILE%\.config\offline-sky`. Back it up securely and retain it for
  future updates. The APK is locally signed for direct installation; validate
  an AAB with the intended Play App Signing setup before store publication.
- Astronomy coverage is bounded as described in `LIMITATIONS.md`; the catalog
  is selected and pinned rather than complete or remotely updated.

## Current Android release rebuild (2026-10-26)

- `flutter build apk --release` completed from the checked-in source with
  Flutter 3.47.7, Dart 3.13.5, Android SDK 36, NDK 28.2.13676358, and JDK
  21.0.12.1. Dependency resolution did not modify `pubspec.lock`.
- The source build produced `artifacts/skybearing-release.apk`, version 0.1.1
  (version code 2), 58,900,961 bytes, SHA-256
  `f734b998ad9f624c6345e4e4b771793581de7797a9d4e698c4ea8cf4791ee098`.
  It targets API 36, supports API 24+, and includes `armeabi-v7a`, `arm64-v8a`,
  and `x86_64`.
- `apksigner verify` passed with APK Signature Scheme v2 and the retained
  4096-bit release key (signer SHA-256
  `b1fa3f7ca44e92012a96a5265147d061410588819827ae0125bef978f646b209`).
  `zipalign -c -P 16 4` passed. The package contains location and camera
  permissions, no network, audio, or storage permissions.
- `flutter analyze lib test/app_navigation_test.dart` passed with no issues.
- The build emitted non-fatal C initializer and Java compatibility/deprecation
  warnings. Automated tests and emulator/device checks were not rerun in this
  Windows session; the earlier API 36 emulator run is historical. Physical
  device performance and sensor/camera accuracy remain unmeasured.
