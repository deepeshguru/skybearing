import 'dart:math' as math;

class EquatorialJ2000 {
  const EquatorialJ2000({
    required this.rightAscensionHours,
    required this.declinationDegrees,
  });

  final double rightAscensionHours;
  final double declinationDegrees;
}

/// Converts IAU Galactic longitude/latitude to equatorial J2000 coordinates.
/// The rotation is the transpose of the standard ICRS-to-Galactic matrix.
EquatorialJ2000 galacticToEquatorialJ2000({
  required double longitudeDegrees,
  required double latitudeDegrees,
}) {
  if (!longitudeDegrees.isFinite ||
      longitudeDegrees < 0 ||
      longitudeDegrees >= 360) {
    throw const FormatException(
      'Galactic longitude must be in [0, 360) degrees.',
    );
  }
  if (!latitudeDegrees.isFinite ||
      latitudeDegrees < -90 ||
      latitudeDegrees > 90) {
    throw const FormatException(
      'Galactic latitude must be in [-90, 90] degrees.',
    );
  }

  const inverse = [
    [-0.0548755604, 0.4941094279, -0.8676661490],
    [-0.8734370902, -0.4448296300, -0.1980763734],
    [-0.4838350155, 0.7469822445, 0.4559837762],
  ];
  final longitude = longitudeDegrees * math.pi / 180;
  final latitude = latitudeDegrees * math.pi / 180;
  final galacticX = math.cos(latitude) * math.cos(longitude);
  final galacticY = math.cos(latitude) * math.sin(longitude);
  final galacticZ = math.sin(latitude);
  final x =
      inverse[0][0] * galacticX +
      inverse[0][1] * galacticY +
      inverse[0][2] * galacticZ;
  final y =
      inverse[1][0] * galacticX +
      inverse[1][1] * galacticY +
      inverse[1][2] * galacticZ;
  final z =
      inverse[2][0] * galacticX +
      inverse[2][1] * galacticY +
      inverse[2][2] * galacticZ;
  return EquatorialJ2000(
    rightAscensionHours: (math.atan2(y, x) * 12 / math.pi + 24) % 24,
    declinationDegrees: math.asin(z.clamp(-1.0, 1.0)) * 180 / math.pi,
  );
}

List<EquatorialJ2000> milkyWayBandJ2000({int longitudeStepDegrees = 5}) {
  if (longitudeStepDegrees <= 0 || 360 % longitudeStepDegrees != 0) {
    throw const FormatException('Longitude step must divide 360 degrees.');
  }
  return [
    for (final latitude in [-5.0, 0.0, 5.0])
      for (
        var longitude = 0;
        longitude <= 360;
        longitude += longitudeStepDegrees
      )
        galacticToEquatorialJ2000(
          longitudeDegrees: longitude == 360 ? 0 : longitude.toDouble(),
          latitudeDegrees: latitude,
        ),
  ];
}
