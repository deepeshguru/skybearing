# Sky Atlas Offline

Sky Atlas Offline is a Flutter planetarium and sky guide for Android and iPhone.
It calculates local directions for the Sun, Moon, supported planets, stars,
deep sky objects, notable black-hole systems, and the Milky Way from bundled
data. It has no backend, login, online astronomy service, or runtime catalog
download.

## Features

- GPS or manually entered observer coordinates, including elevation
- Live and past/future observation time selection
- Interactive sky map with pinch and press-and-hold zoom, horizon grid,
  constellation stick figures and names, stars, deep-sky targets, Solar System
  objects, and the Milky Way band
- Discover screen with the full bundled catalog browsable by object category
- Offline search by object name, catalog identifier, and bundled aliases
- Object details with calculated azimuth/altitude, equatorial coordinates,
  available catalog measurements, and Solar System rise/set times
- 3D phone pointing guide with adjustable heading and tilt alignment
- Camera preview overlay with pinch zoom and user-adjustable approximate field
  of view
- On-device favorites and location/time preferences

## Google Play Android App Bundle

Rebuild the signed Play release bundle after app changes with
`flutter build appbundle --release`. Save the fresh bundle as
`artifacts/google-play/sky-atlas-offline-release.aab` before uploading it. The
previous bundle predates the app-name change and should not be uploaded.

## Run

Install Flutter 3.47.7, Android SDK platform/build tools 36, Android NDK
28.2.13676358, and JDK 21. From the repository root:

```bash
flutter pub get
flutter run
```

For Android, enable USB debugging on a device or start an emulator. For iOS,
use macOS with compatible full Xcode installed. Flutter uses Swift Package
Manager where the installed Xcode supports it. An iOS build was not run in this
Windows session.

## Build and checks

```bash
flutter analyze
flutter test
python3 tooling/test_catalog.py
flutter test integration_test/offline_workflow_test.dart -d emulator-5554
flutter build apk --debug
flutter build apk --release
```

Run the native astronomy package suite from its package directory:

```bash
cd packages/astro_engine
dart test -r expanded
cd ../..
```

See [build instructions](docs/BUILD.md), [test results and device checks](docs/TESTING.md),
and [known limits](docs/LIMITATIONS.md) before distributing a build.

## Data and licenses

The app bundles HYG v4.1 stars, OpenNGC deep-sky objects, Stellarium modern
constellation figures, and a separate SIMBAD-derived notable-target file. The
data sources, pinned revisions, transformations, and license conditions are
listed in [offline data documentation](docs/OFFLINE_DATA.md) and
`assets/licenses/`. Astronomy calculations use the MIT-licensed Astronomy
Engine C library through Dart FFI.

## Project notes

- [Technical review](docs/TECHNICAL_REVIEW.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Astronomy models and coordinate conventions](docs/ASTRONOMY.md)
- [Implementation state](docs/PROGRESS.md)
