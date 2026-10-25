import 'package:astro_engine/astro_engine.dart';

import 'celestial_object.dart';

class CelestialTarget {
  const CelestialTarget.catalog(this.catalogObject) : solarBody = null;
  const CelestialTarget.solar(this.solarBody) : catalogObject = null;

  final CelestialObject? catalogObject;
  final SolarBody? solarBody;

  String get id => catalogObject?.id ?? 'solar:${solarBody!.name}';
  String get name => catalogObject?.name ?? _solarName(solarBody!);
  CelestialType get type => catalogObject?.type ?? CelestialType.solarSystem;
  String get kind => catalogObject == null
      ? _solarKind(solarBody!)
      : _catalogKind(catalogObject!.type);
  String get description =>
      catalogObject?.description ?? _solarDescription(solarBody!);
  List<String> get aliases => catalogObject?.aliases ?? [name, solarBody!.name];
  String get source => catalogObject?.source ?? 'Astronomy Engine';
  double? get magnitude => catalogObject?.magnitude;
  String? get magnitudeBand => catalogObject?.magnitudeBand;
  double? get distanceLightYears => catalogObject?.distanceLightYears;
  String? get constellation => catalogObject?.constellation;

  double? get rightAscensionHoursJ2000 =>
      catalogObject?.rightAscensionHoursJ2000;
  double? get declinationDegreesJ2000 => catalogObject?.declinationDegreesJ2000;

  static List<CelestialTarget> get solarSystem =>
      SolarBody.values.map(CelestialTarget.solar).toList(growable: false);

  static String _solarName(SolarBody body) => switch (body) {
    SolarBody.sun => 'Sun',
    SolarBody.moon => 'Moon',
    SolarBody.mercury => 'Mercury',
    SolarBody.venus => 'Venus',
    SolarBody.mars => 'Mars',
    SolarBody.jupiter => 'Jupiter',
    SolarBody.saturn => 'Saturn',
    SolarBody.uranus => 'Uranus',
    SolarBody.neptune => 'Neptune',
    SolarBody.pluto => 'Pluto',
  };

  static String _solarKind(SolarBody body) => switch (body) {
    SolarBody.sun => 'Star',
    SolarBody.moon => 'Natural satellite',
    SolarBody.pluto => 'Dwarf planet',
    _ => 'Planet',
  };

  static String _catalogKind(CelestialType type) => switch (type) {
    CelestialType.star => 'Star',
    CelestialType.galaxy => 'Galaxy',
    CelestialType.galaxyPair => 'Galaxy pair',
    CelestialType.galaxyGroup => 'Galaxy group',
    CelestialType.globularCluster => 'Globular cluster',
    CelestialType.openCluster => 'Open cluster',
    CelestialType.nebula => 'Nebula',
    CelestialType.planetaryNebula => 'Planetary nebula',
    CelestialType.emissionNebula => 'Emission nebula',
    CelestialType.darkNebula => 'Dark nebula',
    CelestialType.supernovaRemnant => 'Supernova remnant',
    CelestialType.blackHole => 'Black hole',
    CelestialType.solarSystem => 'Solar system object',
    CelestialType.other => 'Other',
  };

  static String _solarDescription(SolarBody body) => switch (body) {
    SolarBody.sun => 'The star at the center of the Solar System.',
    SolarBody.moon => 'Earth’s natural satellite. Phase and position are calculated for the selected time.',
    SolarBody.pluto =>
      'The dwarf planet Pluto, calculated with Astronomy Engine.',
    _ =>
      '${_solarName(body)} is calculated with Astronomy Engine for the selected time and observer.',
  };
}
