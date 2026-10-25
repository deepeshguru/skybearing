# Astronomy and coordinate conventions

## Engine and reference frames

The app vendors Astronomy Engine 2.1.19 from upstream commit
`61dc07020aaa6885d2c7f688a4d82beaf6edb9ef` and calls it through the C wrapper
in `packages/astro_engine/src/astro_bridge.c`. The native C implementation is
compiled by a Flutter native-assets hook; Dart owns typed models and does not
reimplement the planetary ephemeris.

- Public azimuth is normalized to `[0°, 360°)`, clockwise from true north.
- Altitude is `[-90°, +90°]`, positive above the local astronomical horizon.
- The internal local Cartesian frame is East-North-Up (ENU).
- Position times are UTC internally. Date/time pickers accept device-local
  civil time and convert it to UTC before calculation.
- The observer includes geodetic latitude, longitude, and elevation in meters.
- Solar System equatorial coordinates are requested for the observer and date;
  local horizontal directions are topocentric. Horizon calculations use
  `REFRACTION_NONE`, so altitude and horizon status are geometric/no-refraction
  values.
- Catalog coordinates are reference coordinates, not current sky directions.
  They are transformed from J2000 through Astronomy Engine's EQJ→HOR and
  EQJ→EQD rotations for each snapshot.

## Moving catalog coordinates

HYG star entries carry J2000 RA/Dec and proper motion. HYG `pmra` is
`mu_alpha*cos(dec)`; the bridge propagates both proper-motion components in a
three-dimensional tangent plane before applying the date-dependent Astronomy
Engine rotation. This handles RA wraparound and high declinations more safely
than adding an RA offset directly.

The bundled star catalog has no consistently available parallax and radial
velocity for every selected star. The app therefore does not apply individual
topocentric stellar parallax or perspective acceleration. Deep-sky coordinates
are treated as fixed extragalactic/nebular reference positions; their proper
motion is negligible at this map's precision. Stars without catalog proper
motion are held at their J2000 direction before precession/nutation rotation.

The Milky Way band is generated from the IAU J2000 Galactic coordinate frame:
three great-circle samples at Galactic latitudes −5°, 0°, and +5° are
converted to equatorial J2000 and then passed through the same native date and
observer transform. It is a schematic Galactic-plane band, not a photographic
Milky Way brightness map.

## Apparent versus visible

Planet/Sun/Moon directions use Astronomy Engine's apparent equatorial option
for aberration, then an airless/geometric horizon transform. Atmospheric
refraction is intentionally omitted so that the app does not silently mix a
geometric coordinate with a weather-dependent optical correction. Rise/set
events use the engine's zero-altitude horizon threshold; they do not model
terrain, refraction, twilight, or the upper limb of an extended body.

“Above the horizon” is a geometry result, not a claim that a person can see an
object. Catalog magnitude is shown only when supplied. Approximate naked-eye
guidance depends on magnitude and altitude and cannot account for clouds, light
pollution, extinction, the user's eyesight, or optical equipment.

## Device pointing math

Native orientation streams normalize the phone's rear-camera forward axis and
screen right/up axes into ENU. Android uses a rotation-vector sensor and
corrects magnetic north by the geomagnetic declination for the observer
location when known. iOS uses Core Motion's true-north reference frame when it
is available and otherwise reports magnetic north. Display rotation is
applied to screen right/up axes.

For a target unit vector `t` and camera forward vector `f`, angular separation
is `acos(clamp(dot(t, f), -1, 1))`. Horizontal and vertical movement signs come
from projecting the target onto the phone's normalized screen-right and
screen-up vectors. This avoids azimuth subtraction across 0°/360° and accounts
for phone tilt. The default alignment tolerance is 2°; sensor uncertainty is
shown separately.

## Rise/set and phase support

Astronomy Engine calculates rise and set for the integrated Solar System
bodies. The app displays these events in the device's local time zone. At
polar latitudes, a missing rise/set event in the engine search interval is
shown as unavailable rather than fabricated. Catalog stars/deep-sky objects
show their current horizon status; catalog rise/set and transit times are not
currently calculated.

Moon illumination and phase angle use Astronomy Engine. The Sun's illumination
is reported as 1.0 by definition. Other unavailable distance, phase, or
magnitude values remain absent in the UI.

## Independent positional checks

The native test suite compares the Sun, Moon, seven supported non-Earth
planets, and Pluto against NASA/JPL Horizons airless
topocentric azimuth/elevation for 2024-04-08 18:00 UTC at latitude 32.7767° N,
longitude 96.7970° W, elevation 140 m. Each azimuth and altitude error is
asserted below 0.1°. The fixture is in
`packages/astro_engine/test/astro_engine_test.dart`; the Horizons API query
conditions are recorded next to it.

This validates one shared timestamp/location against that model and those
conventions. It is not a guarantee of 0.1° at all dates, locations, or for
sensor alignment. Catalog star coordinates have not been independently
cross-checked against a second full astrometric catalog.
