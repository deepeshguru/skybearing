import 'dart:math' as math;

class EnuVector {
  const EnuVector(this.east, this.north, this.up);

  final double east;
  final double north;
  final double up;

  double get length => math.sqrt(east * east + north * north + up * up);

  EnuVector normalized() {
    final magnitude = length;
    if (!magnitude.isFinite || magnitude == 0) return this;
    return EnuVector(east / magnitude, north / magnitude, up / magnitude);
  }

  double dot(EnuVector other) =>
      east * other.east + north * other.north + up * other.up;

  EnuVector operator +(EnuVector other) =>
      EnuVector(east + other.east, north + other.north, up + other.up);

  EnuVector operator -(EnuVector other) =>
      EnuVector(east - other.east, north - other.north, up - other.up);

  EnuVector operator *(double scalar) =>
      EnuVector(east * scalar, north * scalar, up * scalar);

  static EnuVector fromAzimuthAltitude(
    double azimuthDegrees,
    double altitudeDegrees,
  ) {
    final azimuth = azimuthDegrees * math.pi / 180;
    final altitude = altitudeDegrees * math.pi / 180;
    final cosAltitude = math.cos(altitude);
    return EnuVector(
      math.sin(azimuth) * cosAltitude,
      math.cos(azimuth) * cosAltitude,
      math.sin(altitude),
    );
  }
}

class ObjectAlignment {
  const ObjectAlignment({
    required this.angularSeparationDegrees,
    required this.horizontalErrorDegrees,
    required this.verticalErrorDegrees,
    required this.isAligned,
  });

  final double angularSeparationDegrees;
  final double horizontalErrorDegrees;
  final double verticalErrorDegrees;
  final bool isAligned;
}

ObjectAlignment calculateAlignment({
  required EnuVector target,
  required EnuVector cameraForward,
  required EnuVector screenRight,
  required EnuVector screenUp,
  double toleranceDegrees = 2.0,
}) {
  final targetUnit = target.normalized();
  final forward = cameraForward.normalized();
  final dot = forward.dot(targetUnit).clamp(-1.0, 1.0);
  final separation = math.acos(dot) * 180 / math.pi;
  final horizontal =
      math.atan2(targetUnit.dot(screenRight.normalized()), dot) * 180 / math.pi;
  final vertical =
      math.atan2(targetUnit.dot(screenUp.normalized()), dot) * 180 / math.pi;
  return ObjectAlignment(
    angularSeparationDegrees: separation,
    horizontalErrorDegrees: horizontal,
    verticalErrorDegrees: vertical,
    isAligned: separation <= toleranceDegrees,
  );
}

double normalizeAzimuth(double degrees) => (degrees % 360 + 360) % 360;

double signedAngleDifference(double fromDegrees, double toDegrees) =>
    ((toDegrees - fromDegrees + 540) % 360) - 180;
