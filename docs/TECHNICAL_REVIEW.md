# Technical review

Review performed before project implementation, 2026-10-16.

## Decisions

- **Flutter/Dart is a good fit.** The product is a single interactive application on iOS and Android, with most rendering and business logic shared. A Flutter `CustomPainter` is sufficient for a 2D planetarium with a few thousand filtered points; a custom GPU renderer should be considered only after profiling. Full Xcode is unavailable on this machine, so iOS builds cannot currently be verified.
- **Astronomy Engine is suitable for the Solar System core.** Its upstream project is MIT-licensed, dependency-light, and targets about one arcminute for supported solar-system calculations. Use its C implementation from the same FFI library on both platforms to avoid divergence between platform calculations. It is not a star/deep-sky catalog and does not claim precision appropriate for every use case (e.g. spacecraft navigation).
- **FFI has packaging cost, but is justified here.** A small C ABI wrapper around the upstream C API keeps Dart independent of C structs and provides identical solar-system results on both platforms. Compile it through Flutter's native-assets hook for Android and iOS. Flutter enables Swift Package Manager by default for supported iOS projects, but it needs compatible full Xcode; without Xcode, this workspace's generated plugin metadata reports SPM disabled. CocoaPods 1.17.0 is installed as a fallback. Re-run `flutter pub get` after installing Xcode and verify the selected dependency manager. Keep upstream headers, source and license. Keep catalog-star transforms in documented Dart math using the engine's frame rotation/horizon routines (or a validated equivalent).
- **Flutter remains responsible for UI, storage, camera, and orchestration.** SQLite is appropriate for prepackaged indexed catalog data, favorites, and preferences. Native location and fused motion are exposed through platform APIs; a generic compass stream alone is insufficient for 3D aiming.

## Catalog and redistribution review

- **HYG** provides a convenient broad star set with magnitudes and proper motion, but its GitHub repository was archived in February 2025. The reviewed license is CC BY-SA 4.0. A magnitude-limited adapted catalog may be bundled if attribution, change notices, and ShareAlike terms are preserved. Pin a version and document the epoch/fields. The data is adequate for an offline visual sky, not precision astrometry for every star.
- **OpenNGC** is actively released (reviewed latest tag `v20260501`) and is CC BY-SA 4.0. It is suitable for a practical offline NGC/IC deep-sky catalog. The app must retain attribution and license the adapted database accordingly. Catalog positions and brightnesses have heterogeneous source precision; they are not all equivalent to modern astrometry.
- Use Stellarium's `modern` skyculture data for constellation stick figures and names only, after preserving its data attribution and CC BY-SA 4.0 notice. The IAU's 88 names are a boundary convention; stick figures are illustrative, not official boundaries. Include all 88 names/codes and only render line segments whose endpoints exist in the packaged star subset.
- Object positions or discovery claims for black holes and other special targets should be catalog-backed and clearly shown as approximate sky markers. Avoid unsupported values and do not imply that a marker means the object is visually observable.

## Accuracy and coordinate treatment

- Solar-system body positions must be calculated for the selected UTC instant and observer, including topocentric parallax for the Moon. Keep geometric and apparent coordinates distinct. Refraction is atmospheric and highly variable near the horizon; show unrefracted geometric altitude by default and optionally use a clearly labeled standard-atmosphere estimate.
- Catalog star positions need reference epoch, frame, proper motion, and where available parallax/radial velocity handled before conversion to horizontal coordinates. A J2000 coordinate is not today's azimuth/altitude. Bright-star navigation should document catalog limitations; deep-sky proper motion is normally negligible at this product's visual precision.
- Horizontal convention: azimuth is degrees clockwise from true north (N=0, E=90); altitude is degrees above the astronomical horizon. Use UTC internally; local time is a presentation/input concern.
- Rise/set searches need a body-specific horizon definition (solar limb/refraction, lunar semidiameter/parallax, or a configurable stellar altitude threshold). Near polar regions an event can be absent or continuous; never invent a timestamp.
- Pointing guidance must compare normalized 3D direction vectors, accounting for roll/pitch as well as azimuth. Use a world-coordinate convention (ENU) and explicitly map device/camera axes. A 2D heading cannot support reliable camera overlay placement.

## Device and offline limitations

- GNSS can work without data service on a capable handset, but a first fix may be slow and availability depends on sky view; altitude is less stable than horizontal position. Saved/manual coordinates remain necessary. Do not promise network-assisted positioning offline.
- Magnetometers are disturbed by cases, speakers, vehicles, and local metal. Gyroscopes drift; accelerometers are noisy during movement. iOS true heading is location-dependent, and iOS Simulator has no real magnetic heading. Android rotation-vector quality and availability vary. Display uncertainty/calibration state and make manual exploration work without sensors.
- Camera + orientation overlays are not equivalent to calibrated ARKit/ARCore tracking. Lens field of view, digital crop, stabilization, sensor-camera alignment, interface rotation, and device-specific offsets require calibration and physical-device validation. Present the overlay as an approximate directional aid, not a verified image registration.
- Core functionality can be fully offline once binaries and catalog assets are packaged: ephemerides, catalog search, rendering, manual location, saved data, time travel, and calculations. GPS satellite acquisition may be offline but is hardware-dependent. No runtime data service is required.

## Risks and architecture changes

1. The requested “all significant objects” set is open-ended. Ship pinned, attributable catalogs and expose catalog scope/epoch rather than implying completeness.
2. Phone sensors usually dominate pointing error; a mathematically accurate ephemeris does not guarantee sub-degree real-world alignment. Surface orientation uncertainty separately from calculation precision.
3. Keep native work narrow: location, fused attitude/heading, and camera access. Put object models, transformations, 3D alignment, rendering, and offline search in shared Dart code.
4. Bundle compressed source catalogs and generate a compact indexed SQLite database at build/provisioning time; avoid parsing multi-megabyte CSVs on startup.
5. iOS release verification depends on full Xcode and physical hardware/signing. Android verification depends on Flutter, Android SDK/NDK, and an emulator/device. Report each stage separately.

## Sources reviewed

- Astronomy Engine upstream and C reference: <https://github.com/cosinekitty/astronomy> (MIT; current reviewed release 2.1.19; approximately arcminute target).
- HYG repository/license: <https://github.com/astronexus/HYG-Database> (archived 2025-02-14; CC BY-SA 4.0).
- OpenNGC releases: <https://github.com/mattiaverga/OpenNGC/releases> (reviewed `v20260501`; CC BY-SA 4.0).
- Flutter installation and platform setup: <https://docs.flutter.dev/install/manual>.
- Flutter iOS dependency management (Swift Package Manager default since Flutter 3.44): <https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers>.
- Apple Core Location heading behavior: <https://developer.apple.com/documentation/corelocation/getting-heading-and-course-information>.
- Android rotation-vector sensors: <https://developer.android.com/develop/sensors-and-location/sensors/sensors_position>.
