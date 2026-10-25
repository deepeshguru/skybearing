import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

import 'astro_engine_bindings_generated.dart' as bindings;

enum SolarBody {
  sun(0),
  moon(1),
  mercury(2),
  venus(3),
  mars(4),
  jupiter(5),
  saturn(6),
  uranus(7),
  neptune(8),
  pluto(9);

  const SolarBody(this.nativeId);
  final int nativeId;
}

class NativeSkyPosition {
  const NativeSkyPosition({
    required this.rightAscensionHours,
    required this.declinationDegrees,
    required this.azimuthDegrees,
    required this.altitudeDegrees,
    this.distanceAu,
    this.visualMagnitude,
    this.illuminatedFraction,
    this.phaseAngleDegrees,
  });

  final double rightAscensionHours;
  final double declinationDegrees;
  final double azimuthDegrees;
  final double altitudeDegrees;
  final double? distanceAu;
  final double? visualMagnitude;
  final double? illuminatedFraction;
  final double? phaseAngleDegrees;

  bool get isAboveHorizon => altitudeDegrees >= 0;
}

class NativeCatalogCoordinate {
  const NativeCatalogCoordinate({
    required this.rightAscensionHoursJ2000,
    required this.declinationDegreesJ2000,
    this.properMotionRaMasPerYear = 0,
    this.properMotionDecMasPerYear = 0,
  });

  final double rightAscensionHoursJ2000;
  final double declinationDegreesJ2000;
  final double properMotionRaMasPerYear;
  final double properMotionDecMasPerYear;
}

class NativeCatalogPosition {
  const NativeCatalogPosition({
    required this.rightAscensionHoursOfDate,
    required this.declinationDegreesOfDate,
    required this.azimuthDegrees,
    required this.altitudeDegrees,
  });

  final double rightAscensionHoursOfDate;
  final double declinationDegreesOfDate;
  final double azimuthDegrees;
  final double altitudeDegrees;
}

class OfflineAstronomyEngine {
  const OfflineAstronomyEngine();

  NativeSkyPosition position({
    required SolarBody body,
    required DateTime utc,
    required double latitudeDegrees,
    required double longitudeDegrees,
    required double elevationMeters,
  }) {
    final output = calloc<Double>(8);
    try {
      final date = utc.toUtc();
      final status = bindings.offline_sky_body_position(
        body.nativeId,
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second + date.millisecond / 1000 + date.microsecond / 1000000,
        latitudeDegrees,
        longitudeDegrees,
        elevationMeters,
        output,
      );
      _checkStatus(status, 'position');
      return NativeSkyPosition(
        rightAscensionHours: output[0],
        declinationDegrees: output[1],
        azimuthDegrees: _normalize(output[2]),
        altitudeDegrees: output[3],
        distanceAu: _nullable(output[4]),
        visualMagnitude: _nullable(output[5]),
        illuminatedFraction: _nullable(output[6]),
        phaseAngleDegrees: _nullable(output[7]),
      );
    } finally {
      calloc.free(output);
    }
  }

  DateTime? riseSet({
    required SolarBody body,
    required bool rising,
    required DateTime utcStart,
    required double latitudeDegrees,
    required double longitudeDegrees,
    required double elevationMeters,
    double limitDays = 2,
  }) {
    final date = utcStart.toUtc();
    final seconds = bindings.offline_sky_rise_set(
      body.nativeId,
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second + date.millisecond / 1000 + date.microsecond / 1000000,
      latitudeDegrees,
      longitudeDegrees,
      elevationMeters,
      rising ? 1 : -1,
      limitDays,
    );
    if (!seconds.isFinite) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    );
  }

  List<NativeCatalogPosition> catalogPositions({
    required List<NativeCatalogCoordinate> coordinates,
    required DateTime utc,
    required double latitudeDegrees,
    required double longitudeDegrees,
    required double elevationMeters,
  }) {
    if (coordinates.isEmpty) return const [];
    final input = calloc<Double>(coordinates.length * 4);
    final output = calloc<Double>(coordinates.length * 4);
    try {
      for (var index = 0; index < coordinates.length; index++) {
        final coordinate = coordinates[index];
        final offset = index * 4;
        input[offset] = coordinate.rightAscensionHoursJ2000;
        input[offset + 1] = coordinate.declinationDegreesJ2000;
        input[offset + 2] = coordinate.properMotionRaMasPerYear;
        input[offset + 3] = coordinate.properMotionDecMasPerYear;
      }
      final date = utc.toUtc();
      final status = bindings.offline_sky_catalog_positions(
        coordinates.length,
        input,
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second + date.millisecond / 1000 + date.microsecond / 1000000,
        latitudeDegrees,
        longitudeDegrees,
        elevationMeters,
        output,
      );
      _checkStatus(status, 'catalog positions');
      return List<NativeCatalogPosition>.generate(coordinates.length, (index) {
        final offset = index * 4;
        return NativeCatalogPosition(
          rightAscensionHoursOfDate: output[offset],
          declinationDegreesOfDate: output[offset + 1],
          azimuthDegrees: _normalize(output[offset + 2]),
          altitudeDegrees: output[offset + 3],
        );
      }, growable: false);
    } finally {
      calloc.free(input);
      calloc.free(output);
    }
  }

  void _checkStatus(int status, String operation) {
    if (status != 0) {
      throw StateError('Astronomy Engine $operation failed (status $status).');
    }
  }

  double _normalize(double degrees) => (degrees % 360 + 360) % 360;

  double? _nullable(double value) => value.isFinite ? value : null;
}

double angularSeparationDegrees(
  double ra1Hours,
  double dec1Degrees,
  double ra2Hours,
  double dec2Degrees,
) {
  final ra1 = ra1Hours * math.pi / 12;
  final ra2 = ra2Hours * math.pi / 12;
  final dec1 = dec1Degrees * math.pi / 180;
  final dec2 = dec2Degrees * math.pi / 180;
  final cosine =
      math.sin(dec1) * math.sin(dec2) +
      math.cos(dec1) * math.cos(dec2) * math.cos(ra1 - ra2);
  return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
}
