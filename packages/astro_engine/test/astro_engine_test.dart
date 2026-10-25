import 'dart:math' as math;

import 'package:astro_engine/astro_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = OfflineAstronomyEngine();
  final utc = DateTime.utc(2024, 4, 8, 18);
  const latitude = 32.7767;
  const longitude = -96.7970;
  const elevation = 140.0;

  // Independent NASA/JPL Horizons observer ephemeris. Query conditions:
  // UT 2024-04-08 18:00:00, geodetic observer (-96.7970 E, 32.7767 N,
  // 0.140 km), apparent airless AZ/EL (quantity 4). JPL reports azimuth
  // clockwise from north and elevation above the local horizon.
  // https://ssd.jpl.nasa.gov/api/horizons.api
  const reference = <SolarBody, (double, double)>{
    SolarBody.sun: (163.560119941, 63.937196652),
    SolarBody.moon: (164.130188583, 63.787919112),
    SolarBody.mercury: (150.801840987, 67.032892508),
    SolarBody.venus: (191.155244324, 57.114090093),
    SolarBody.mars: (215.874980715, 42.540736438),
    SolarBody.jupiter: (107.406007660, 53.713261351),
    SolarBody.saturn: (214.209160419, 43.380521880),
    SolarBody.uranus: (104.185454126, 52.670593947),
    SolarBody.neptune: (200.261341967, 53.611629031),
    SolarBody.pluto: (237.872643829, 6.357253043),
  };

  group('Solar System calculations vs JPL Horizons', () {
    for (final entry in reference.entries) {
      test(entry.key.name, () {
        final result = engine.position(
          body: entry.key,
          utc: utc,
          latitudeDegrees: latitude,
          longitudeDegrees: longitude,
          elevationMeters: elevation,
        );
        expect(
          _angleDifference(result.azimuthDegrees, entry.value.$1),
          lessThan(0.1),
        );
        expect((result.altitudeDegrees - entry.value.$2).abs(), lessThan(0.1));
        expect(result.rightAscensionHours, inInclusiveRange(0.0, 24.0));
        expect(result.declinationDegrees, inInclusiveRange(-90.0, 90.0));
      });
    }
  });

  test('Moon illumination and phase values are bounded', () {
    final moon = engine.position(
      body: SolarBody.moon,
      utc: utc,
      latitudeDegrees: latitude,
      longitudeDegrees: longitude,
      elevationMeters: elevation,
    );
    expect(moon.illuminatedFraction, inInclusiveRange(0.0, 1.0));
    expect(moon.phaseAngleDegrees, inInclusiveRange(0.0, 360.0));
    expect(moon.distanceAu, greaterThan(0));
  });

  test('Sun rise and set return actual event times', () {
    final set = engine.riseSet(
      body: SolarBody.sun,
      rising: false,
      utcStart: utc,
      latitudeDegrees: latitude,
      longitudeDegrees: longitude,
      elevationMeters: elevation,
      limitDays: 1,
    );
    expect(set, isNotNull);
    expect(set!.isAfter(utc), isTrue);
    expect(set.difference(utc), lessThan(const Duration(hours: 12)));
  });

  test(
    'Catalog proper motion and epoch transforms return valid sky coordinates',
    () {
      final positions = engine.catalogPositions(
        coordinates: const [
          NativeCatalogCoordinate(
            rightAscensionHoursJ2000: 6.752481,
            declinationDegreesJ2000: -16.716116,
            properMotionRaMasPerYear: -546.01,
            properMotionDecMasPerYear: -1223.07,
          ),
          NativeCatalogCoordinate(
            rightAscensionHoursJ2000: 0,
            declinationDegreesJ2000: 0,
          ),
        ],
        utc: utc,
        latitudeDegrees: latitude,
        longitudeDegrees: longitude,
        elevationMeters: elevation,
      );
      expect(positions, hasLength(2));
      for (final position in positions) {
        expect(position.rightAscensionHoursOfDate, inInclusiveRange(0.0, 24.0));
        expect(
          position.declinationDegreesOfDate,
          inInclusiveRange(-90.0, 90.0),
        );
        expect(position.azimuthDegrees, inInclusiveRange(0.0, 360.0));
        expect(position.altitudeDegrees, inInclusiveRange(-90.0, 90.0));
      }
    },
  );

  test('angular separation handles RA wraparound', () {
    expect(
      angularSeparationDegrees(23.999, 0, 0.001, 0),
      closeTo(0.03, 0.0001),
    );
    expect(angularSeparationDegrees(5, 12, 5, 12), closeTo(0, 1e-8));
  });
}

double _angleDifference(double a, double b) {
  final raw = (a - b).abs() % 360;
  return math.min(raw, 360 - raw);
}
