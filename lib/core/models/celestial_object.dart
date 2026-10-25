enum CelestialType {
  star,
  galaxy,
  galaxyPair,
  galaxyGroup,
  globularCluster,
  openCluster,
  nebula,
  planetaryNebula,
  emissionNebula,
  darkNebula,
  supernovaRemnant,
  blackHole,
  solarSystem,
  other,
}

CelestialType celestialTypeFromName(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('star')) return CelestialType.star;
  if (normalized.contains('galaxy pair')) return CelestialType.galaxyPair;
  if (normalized.contains('galaxy group')) return CelestialType.galaxyGroup;
  if (normalized.contains('galaxy')) return CelestialType.galaxy;
  if (normalized.contains('globular')) return CelestialType.globularCluster;
  if (normalized.contains('open cluster')) return CelestialType.openCluster;
  if (normalized.contains('planetary nebula')) {
    return CelestialType.planetaryNebula;
  }
  if (normalized.contains('dark nebula')) return CelestialType.darkNebula;
  if (normalized.contains('emission nebula')) {
    return CelestialType.emissionNebula;
  }
  if (normalized.contains('nebula')) return CelestialType.nebula;
  if (normalized.contains('supernova remnant')) {
    return CelestialType.supernovaRemnant;
  }
  if (normalized.contains('black hole')) return CelestialType.blackHole;
  return CelestialType.other;
}

class CelestialObject {
  const CelestialObject({
    required this.id,
    required this.name,
    required this.type,
    required this.rightAscensionHoursJ2000,
    required this.declinationDegreesJ2000,
    required this.epoch,
    required this.description,
    required this.aliases,
    required this.source,
    this.properMotionRaMasPerYear,
    this.properMotionDecMasPerYear,
    this.magnitude,
    this.magnitudeBand,
    this.distanceLightYears,
    this.constellation,
  });

  final String id;
  final String name;
  final CelestialType type;
  final double rightAscensionHoursJ2000;
  final double declinationDegreesJ2000;
  final double epoch;
  final double? properMotionRaMasPerYear;
  final double? properMotionDecMasPerYear;
  final double? magnitude;
  final String? magnitudeBand;
  final double? distanceLightYears;
  final String? constellation;
  final String description;
  final List<String> aliases;
  final String source;

  bool get isStar => type == CelestialType.star;
  bool get isSolarSystemObject => type == CelestialType.solarSystem;
}

class Constellation {
  const Constellation({
    required this.abbreviation,
    required this.name,
    required this.aliases,
  });

  final String abbreviation;
  final String name;
  final List<String> aliases;
}

class ConstellationSegment {
  const ConstellationSegment({
    required this.abbreviation,
    required this.fromHip,
    required this.toHip,
  });

  final String abbreviation;
  final int fromHip;
  final int toHip;
}
