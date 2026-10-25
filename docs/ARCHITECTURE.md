# Architecture

## Runtime layers

```text
Flutter UI (Riverpod)
  ├── sky map painter, search, details, locator, camera overlay
  ├── catalog repository ── bundled read-only SQLite + notable_objects.json
  ├── location service ──── Android/iOS OS location APIs through Geolocator
  └── astronomy service ─── C Astronomy Engine through Dart FFI
                              └── catalog batch transforms in a Dart isolate

Native Android Kotlin / iOS Swift
  └── fused motion sensors → Method/EventChannel → normalized ENU camera frame
```

## Data flow

1. On first catalog use, `CatalogRepository` copies the prepackaged SQLite file
   into application documents and opens it read-only. Search and favorite IDs
   stay local. The separate notable-target JSON is loaded from the app bundle.
2. Location and observation time are held in `SkyController`; saved values and
   favorites use on-device shared preferences. GPS failures preserve any saved
   location and provide a manual coordinate path.
3. `skySnapshotProvider` loads the catalog once, then calculates the star,
   deep-sky, black-hole, Milky Way, Sun, Moon, and planet positions for a
   location/time snapshot. The catalog batch is calculated in an isolate so
   native catalog transforms do not block the Flutter UI. Solar System bodies
   are calculated separately through the C API.
4. The snapshot refreshes when location or observation time changes and every
   30 seconds in live mode. Sensor updates remain independent; they update the
   device-following projection and locator without rerunning the ephemeris.
5. `CustomPainter` projects cached ENU direction vectors into the current
   field of view. It draws catalog brightness, constellation figures/names,
   horizon/altitude grid, planets, notable targets, and the derived Milky Way
   band. Panning/zooming is local view state.
6. Locator guidance compares normalized 3D target and phone vectors. Camera
   mode uses the same frame and a screen-aspect field-of-view projection; its
   FOV is user-adjustable and labelled approximate.

## Code map

- `lib/app/`: app shell, Material dark theme, Riverpod state
- `lib/core/astronomy/`: sky snapshots and IAU Galactic coordinate transform
- `lib/core/database/`: prepackaged local catalog repository
- `lib/core/location/`: permission-aware GPS provider
- `lib/core/math/`: ENU vectors and 3D alignment
- `lib/core/models/`: observer, target, catalog, and orientation models
- `lib/core/rendering/`: sky projection
- `lib/core/sensors/`: normalized platform channel contract
- `lib/features/`: sky map, search, details, locator, camera, favorites, settings
- `packages/astro_engine/`: C bridge, vendored Astronomy Engine, native-assets
  build hook, and FFI API
- `assets/catalogs/`: bundled SQLite and notable-target JSON
- `android/app/src/main/kotlin/`: Android rotation-vector sensor channel
- `ios/Runner/AppDelegate.swift`: Core Motion channel registration/stream
- `tooling/`: catalog builder and offline catalog validation
- `docs/`: technical review and implementation documentation

## Platform and lifecycle decisions

- Flutter is used for shared UI; native code is limited to sensor orientation
  normalization. GPS uses the supported Geolocator platform implementations.
- Astronomy Engine is statically compiled for target platforms through Flutter
  native-assets hooks. It is not dynamically downloaded or loaded from a
  server. A single C implementation keeps Android/iOS calculations consistent.
- The camera is optional. Its controller is disposed when the page leaves the
  foreground and released when the route closes.
- Sensor subscriptions are stream-driven and stop when no screen listens or
  the platform activity is paused.
- The release manifest/package has no Android `INTERNET` permission; debug and
  profile variants add it only for Flutter's VM service. Runtime astronomy,
  catalog lookup, and manual-location workflows have no network dependency.

## Deliberate scope boundaries

- The engine covers Sun, Moon, Mercury through Neptune, and Pluto. Astronomy
  Engine does not provide the other dwarf planets in this integration.
- Rise/set times are currently offered for supported Solar System bodies.
- The 88 constellation lines are sky-culture stick figures, not IAU boundary
  polygons.
- Camera overlays use a user-adjustable FOV estimate. Real lens distortion and
  preview crop behavior still need physical-device calibration.
