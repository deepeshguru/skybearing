# Sky Atlas Offline — Google Play release packet

This file contains the proposed public listing values and console declarations
for the Android release.

## Store listing

- **Developer name:** Sky Atlas Offline
- **Support email:** deepeshguru786@gmail.com
- **App name:** Sky Atlas Offline
- **Category:** Education
- **Price:** Free; no ads or in-app purchases
- **Privacy policy:** https://github.com/deepeshguru/skybearing/blob/main/docs/PRIVACY_POLICY.md
- **Short description:** Find stars, planets and constellations with a planetarium that works offline.
- **Full description:**

  Explore the sky above you with an offline planetarium and astronomy guide.
  Sky Atlas Offline calculates the directions of the Sun, Moon, planets, stars,
  and deep-sky objects on your device using its bundled sky catalog.

  **Explore your sky**
  - Browse an interactive sky map with stars, constellations, the Milky Way, and
    a horizon grid.
  - Search the bundled catalog by object name, catalog identifier, or alias.
  - Open object details with sky position, catalog measurements, and rise/set
    times for Solar System objects.
  - Save favorite objects on your device.
  - Choose your observer location with GPS or enter coordinates manually.
  - Select a past, current, or future observation time.
  - Use the phone-pointing guide and optional live camera overlay to help aim
    toward a selected object.

  Astronomy catalogs and calculations are bundled with the app. Core sky
  exploration works without an account, backend, or internet connection.
  Location is processed on your device. The optional camera overlay is an
  approximate aiming aid, not a calibrated optical instrument.

## Graphic assets

- Play icon: `artifacts/google-play/play-store-icon-512.png`
- Feature graphic: `artifacts/google-play/feature-graphic-1024x500.png`
- Phone screenshots: `artifacts/google-play/screenshots/`

Suggested screenshot alt text:

1. “Browse the Sun, Moon, and planets in the offline astronomy catalog.”
2. “Search the bundled sky catalog for Jupiter and related objects.”
3. “Save favorite sky objects locally on your device.”

## Console declarations to review

- **Contains ads:** No.
- **App access:** All features are available without a login.
- **Target audience:** General audience; do not mark as designed specifically
  for children unless that is your intended audience.
- **Permissions:** Location is used on-device for local sky calculations;
  camera is optional and used for a live aiming overlay. Do not describe the
  camera view as recording or saving media.
- **Data safety:** Answer that the app does not collect or share user data.
  Location, camera, sensor, and preference data are used or stored locally and
  the release manifest has no Internet permission. Google's form defines
  collection as transmitting data off-device and excludes on-device-only
  processing. The app's saved observer location is excluded from Android
  backup/device transfer; the OS may back up some other preferences when the
  user enables Android backup. If the dependency set or app behavior changes,
  update the declaration and policy to match.
- **Content rating:** Complete the Play questionnaire truthfully; let Play
  assign the rating.
- **Support website:** The public policy URL above can be used until you provide
  a dedicated support website.

## Release build

- Android application ID: `com.offlinesky.offline_sky`
- Minimum supported Android version: API 24
- Target API: 36
- Current app version: `0.1.2+3`
- **Signed upload bundle:** Rebuild with the updated app name before uploading.
  The existing `offline-sky-release.aab` has the old launcher label and must not
  be used. Build with `flutter build appbundle --release`, then save the new
  bundle as `artifacts/google-play/sky-atlas-offline-release.aab`.
- Enroll in Play App Signing and upload that bundle.
- Keep the existing upload keystore and passwords backed up securely outside
  the repository. Do not regenerate the upload key for updates.
