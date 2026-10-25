# Limitations and release checks

## Astronomical model

- Astronomy Engine is used for supported Solar System bodies and coordinate
  transforms. Its model is not a JPL DE ephemeris distributed with this app.
  One Horizons timestamp/location fixture passes the stated <0.1° assertions;
  broad all-epoch accuracy has not been established by that one fixture.
- The integration includes Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn,
  Uranus, Neptune, and Pluto. The upstream API used here does not expose the
  other dwarf planets.
- Star proper motion is applied when bundled. Parallax and radial velocity are
  not available consistently for the bundled star set; apparent stellar
  positions can therefore differ by arcseconds or more for nearby/high-motion
  stars. Deep-sky object proper motion is ignored.
- Refraction and observer terrain are not applied. Rise/set uses the
  zero-altitude geometric horizon and does not adjust for twilight or a body's
  upper limb. Catalog-object rise/set/transit is not yet implemented.
- Magnitude and altitude do not guarantee naked-eye visibility. Clouds,
  extinction, moonlight, light pollution, optics, and eyesight are not modeled.
- Constellation lines are illustrative stick figures; they are not IAU
  boundary polygons. The Milky Way is a schematic ±5° Galactic-plane band,
  not an all-sky brightness or dust map.
- The bundled notable-target file lists eight black-hole systems plus a
  Galactic Center marker. It is intentionally a selected list, not a complete
  or continuously updated black-hole catalog. A marker denotes the listed
  source/counterpart coordinate, not an optically resolved event horizon.

## Device and camera accuracy

- Phone magnetometers can be biased by nearby steel, magnets, electronics,
  cases, and vehicle structures. Sensor confidence is not a laboratory error
  bound. Figure-eight motion may improve calibration, but real compass accuracy
  depends on the device and environment.
- Android true-north correction uses the platform geomagnetic model when
  observer coordinates are known. iOS requests a Core Motion true-north frame
  where available and otherwise uses magnetic north. Platform/location
  permissions and OS behavior can change the reported reference.
- The camera overlay supports a user-adjustable vertical FOV and handles the
  camera preview's aspect/crop in screen space. It has not been aligned against
  a star field on physical hardware. Lens distortion, stabilization crop,
  camera sensor orientation, and device-specific sensor-to-lens offsets can
  still produce visual error. Treat it as an approximate guide.
- Emulators cannot validate actual GNSS acquisition, magnetic heading quality,
  sensor-to-lens alignment, or outdoor camera accuracy.

## Platform and release

- Android is the only platform build target available in this environment.
  Real-device orientation, GPS, camera, and airplane-mode workflows remain
  physical-device checks.
- Full Xcode/iOS SDKs are absent here. CocoaPods 1.17.0 is installed, but iOS
  compilation, simulator tests, and real iPhone checks remain unverified.
- The Android debug APK is not a signed store release. Owner-managed Android
  release signing and Apple signing/provisioning are required for publication.
- Database change migrations/catalog update strategy have not been added; the
  app deliberately ships pinned bundled data and performs no runtime updates.
