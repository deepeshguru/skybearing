import 'dart:isolate';

import 'package:astro_engine/astro_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'galactic_coordinates.dart';
import '../math/sky_math.dart';
import '../models/celestial_object.dart';
import '../models/observer_location.dart';
import '../../app/providers.dart';

class SkyMapPoint {
  SkyMapPoint({
    required this.object,
    required this.rightAscensionHours,
    required this.declinationDegrees,
    required this.azimuthDegrees,
    required this.altitudeDegrees,
  }) : direction = EnuVector.fromAzimuthAltitude(
         azimuthDegrees,
         altitudeDegrees,
       );

  final CelestialObject object;
  final double rightAscensionHours;
  final double declinationDegrees;
  final double azimuthDegrees;
  final double altitudeDegrees;
  final EnuVector direction;
}

class SolarMapPoint {
  SolarMapPoint(this.body, this.position)
    : direction = EnuVector.fromAzimuthAltitude(
        position.azimuthDegrees,
        position.altitudeDegrees,
      );

  final SolarBody body;
  final NativeSkyPosition position;
  final EnuVector direction;
}

class SkyConstellationPath {
  const SkyConstellationPath({
    required this.abbreviation,
    required this.directions,
  });
  final String abbreviation;
  final List<EnuVector> directions;
}

class SkyConstellationLabel {
  const SkyConstellationLabel({required this.name, required this.direction});
  final String name;
  final EnuVector direction;
}

class SkySnapshot {
  const SkySnapshot({
    required this.utc,
    required this.location,
    required this.catalogPoints,
    required this.solarPoints,
    required this.constellations,
    required this.segments,
    required this.constellationPaths,
    required this.constellationLabels,
    required this.milkyWayCurves,
  });

  final DateTime utc;
  final ObserverLocation location;
  final List<SkyMapPoint> catalogPoints;
  final List<SolarMapPoint> solarPoints;
  final List<Constellation> constellations;
  final List<ConstellationSegment> segments;
  final List<SkyConstellationPath> constellationPaths;
  final List<SkyConstellationLabel> constellationLabels;
  final List<List<EnuVector>> milkyWayCurves;

  SolarMapPoint? solar(SolarBody body) {
    for (final item in solarPoints) {
      if (item.body == body) return item;
    }
    return null;
  }

  SkyMapPoint? catalog(String id) {
    for (final item in catalogPoints) {
      if (item.object.id == id) return item;
    }
    return null;
  }
}

final skySnapshotProvider = FutureProvider.autoDispose<SkySnapshot?>((
  ref,
) async {
  final state = ref.watch(skyStateProvider);
  final location = state.location;
  if (location == null || state.isRestoring) return null;
  final repository = await ref.watch(catalogRepositoryProvider.future);
  final stars = await repository.loadStars();
  final deepSky = await repository.loadDeepSkyObjects();
  final constellations = await repository.loadConstellations();
  final segments = await repository.loadConstellationSegments();
  final utc = state.currentTime.toUtc();
  final inputs = [...stars, ...deepSky];
  final planeCoordinates = milkyWayBandJ2000()
      .map(
        (coordinate) => NativeCatalogCoordinate(
          rightAscensionHoursJ2000: coordinate.rightAscensionHours,
          declinationDegreesJ2000: coordinate.declinationDegrees,
        ),
      )
      .toList(growable: false);
  final positions = await Isolate.run(
    () => _calculatePositions(
      inputs,
      planeCoordinates,
      utc,
      location.latitudeDegrees,
      location.longitudeDegrees,
      location.elevationMeters,
    ),
  );
  final catalogPoints = <SkyMapPoint>[];
  for (var index = 0; index < inputs.length; index++) {
    final row = positions[index];
    catalogPoints.add(
      SkyMapPoint(
        object: inputs[index],
        rightAscensionHours: row[0],
        declinationDegrees: row[1],
        azimuthDegrees: row[2],
        altitudeDegrees: row[3],
      ),
    );
  }
  final starsByHip = <int, SkyMapPoint>{};
  final hipPattern = RegExp(r'^star:hip:(\d+)$');
  for (final point in catalogPoints) {
    final match = hipPattern.firstMatch(point.object.id);
    if (match != null) starsByHip[int.parse(match.group(1)!)] = point;
  }
  final membersByConstellation = <String, Map<int, EnuVector>>{};
  final constellationPaths = <SkyConstellationPath>[];
  for (final segment in segments) {
    final from = starsByHip[segment.fromHip];
    final to = starsByHip[segment.toHip];
    if (from == null || to == null) continue;
    final members = membersByConstellation.putIfAbsent(
      segment.abbreviation,
      () => <int, EnuVector>{},
    );
    members[segment.fromHip] = from.direction;
    members[segment.toHip] = to.direction;
    constellationPaths.add(
      SkyConstellationPath(
        abbreviation: segment.abbreviation,
        directions: List<EnuVector>.generate(11, (step) {
          final t = step / 10;
          return (from.direction * (1 - t) + to.direction * t).normalized();
        }, growable: false),
      ),
    );
  }
  final namesByAbbreviation = {
    for (final constellation in constellations)
      constellation.abbreviation: constellation.name,
  };
  final constellationLabels = <SkyConstellationLabel>[];
  for (final entry in membersByConstellation.entries) {
    final name = namesByAbbreviation[entry.key];
    if (name == null) continue;
    var mean = const EnuVector(0, 0, 0);
    for (final direction in entry.value.values) {
      mean += direction;
    }
    if (mean.length > 0) {
      constellationLabels.add(
        SkyConstellationLabel(name: name, direction: mean.normalized()),
      );
    }
  }
  const pointsPerCurve = 73;
  final milkyWayCurves = List<List<EnuVector>>.generate(3, (curve) {
    final start = inputs.length + curve * pointsPerCurve;
    return List<EnuVector>.generate(pointsPerCurve, (index) {
      final row = positions[start + index];
      return EnuVector.fromAzimuthAltitude(row[2], row[3]);
    }, growable: false);
  }, growable: false);
  const engine = OfflineAstronomyEngine();
  final solarPoints = SolarBody.values
      .map(
        (body) => SolarMapPoint(
          body,
          engine.position(
            body: body,
            utc: utc,
            latitudeDegrees: location.latitudeDegrees,
            longitudeDegrees: location.longitudeDegrees,
            elevationMeters: location.elevationMeters,
          ),
        ),
      )
      .toList(growable: false);
  return SkySnapshot(
    utc: utc,
    location: location,
    catalogPoints: catalogPoints,
    solarPoints: solarPoints,
    constellations: constellations,
    segments: segments,
    constellationPaths: constellationPaths,
    constellationLabels: constellationLabels,
    milkyWayCurves: milkyWayCurves,
  );
});

List<List<double>> _calculatePositions(
  List<CelestialObject> objects,
  List<NativeCatalogCoordinate> galacticPlane,
  DateTime utc,
  double latitude,
  double longitude,
  double elevation,
) {
  const engine = OfflineAstronomyEngine();
  final result = engine.catalogPositions(
    coordinates: [
      ...objects.map(
        (object) => NativeCatalogCoordinate(
          rightAscensionHoursJ2000: object.rightAscensionHoursJ2000,
          declinationDegreesJ2000: object.declinationDegreesJ2000,
          properMotionRaMasPerYear: object.properMotionRaMasPerYear ?? 0,
          properMotionDecMasPerYear: object.properMotionDecMasPerYear ?? 0,
        ),
      ),
      ...galacticPlane,
    ],
    utc: utc,
    latitudeDegrees: latitude,
    longitudeDegrees: longitude,
    elevationMeters: elevation,
  );
  return result
      .map(
        (item) => [
          item.rightAscensionHoursOfDate,
          item.declinationDegreesOfDate,
          item.azimuthDegrees,
          item.altitudeDegrees,
        ],
      )
      .toList(growable: false);
}
