# Testing and device validation

## Automated checks

Run from the project root:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test packages/astro_engine/lib packages/astro_engine/test
flutter analyze
flutter test
python3 tooling/test_catalog.py
flutter test integration_test/offline_workflow_test.dart -d emulator-5554
```

The Astronomy Engine native package has its own tests:

```bash
cd packages/astro_engine
dart test -r expanded
cd ../..
```

The integration test launches the real app on an Android emulator, enters a
manual observer location, searches the bundled catalog for Jupiter, and checks
that the app calculates and displays local azimuth/altitude details. It does
not mock the SQLite catalog or astronomy engine.

Astronomical position fixtures compare the Sun, Moon, seven supported
non-Earth planets, and Pluto against NASA/JPL Horizons airless topocentric
azimuth/elevation for 2024-04-08 18:00 UTC at 32.7767° N, 96.7970° W, 140 m.
Both azimuth and altitude are asserted within 0.1° for that fixture.
Coordinate tests cover the Galactic center and north pole, vector normalization,
azimuth wraparound, horizon boundaries, and sky-map projection. Catalog tests
check SQLite integrity, search/index behavior, all 88 constellations, license
notices, and the notable-target sidecar.

## Manual device checklist

On a real Android phone and iPhone, verify:

1. Deny location access, enter coordinates manually, and calculate the sky.
2. Grant location access and confirm the displayed fix age and accuracy.
3. Test GNSS acquisition with network disabled and separately record whether a
   satellite fix is obtained; this depends on sky view, receiver state, and
   cached almanac data.
4. Compare compass direction in several orientations and environments; note
   magnetic interference and platform calibration prompts.
5. Rotate the device through portrait/landscape and confirm sky-follow and
   locator movement, including 3D tilt.
6. Confirm the camera overlay on a star field, adjusting its vertical field of
   view against the device lens. Overlay placement is approximate until this is
   calibrated on that hardware.
7. Enable airplane mode and use search, object details, favorites, time travel,
   and the sky map after a cold restart.
8. Background/foreground the app while camera and sensor streams are open and
   verify they stop and resume cleanly.

## Executed emulator checks

On 2026-10-16, the API 36 Google APIs emulator ran with Wi-Fi disabled and
mobile data disabled (`adb shell svc wifi disable` and `adb shell svc data
disable`). The release APK was installed and launched; the saved manual Dallas
observer rendered the bundled sky and returned local search results and
calculated Jupiter coordinates. The emulator also exercised saved objects,
time travel, locator guidance, and the camera-preview flow. Its simulated
heading and camera image do not validate physical sensors or optical alignment.

The release APK permission table was inspected with Android `aapt`: it has no
`INTERNET`, `ACCESS_NETWORK_STATE`, audio-recording, or storage permissions.
Flutter's debug and profile manifests add `INTERNET` for the VM service, so a
network-disabled emulator session is used when checking debug builds offline.

Android build and test counts are reported in `docs/PROGRESS.md`. No physical
Android phone is attached. The current machine lacks full Xcode and the iOS
SDKs, so iOS build, simulator, and iPhone checks remain blocked. CocoaPods
1.17.0 is installed; after Xcode is available, rerun `flutter pub get` and
confirm Flutter's selected iOS dependency manager before building. These limits
are not passing platform tests.
