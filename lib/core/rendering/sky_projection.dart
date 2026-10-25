import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../math/sky_math.dart';

double starMagnitudeLimitForFieldOfView(double fieldOfViewDegrees) {
  final fov = fieldOfViewDegrees.clamp(32.0, 150.0).toDouble();
  return (7.3 - fov * 0.025).clamp(4.2, 6.6).toDouble();
}

class SkyProjection {
  SkyProjection({
    required this.centerAzimuthDegrees,
    required this.centerAltitudeDegrees,
    required this.fieldOfViewDegrees,
  }) : _center = EnuVector.fromAzimuthAltitude(
         centerAzimuthDegrees,
         centerAltitudeDegrees,
       ),
       _right = _makeRight(centerAzimuthDegrees),
       _up = _makeUp(centerAzimuthDegrees, centerAltitudeDegrees),
       _tanHalfFieldOfView = math.tan(fieldOfViewDegrees * math.pi / 360);

  final double centerAzimuthDegrees;
  final double centerAltitudeDegrees;
  final double fieldOfViewDegrees;
  final EnuVector _center;
  final EnuVector _right;
  final EnuVector _up;
  final double _tanHalfFieldOfView;
  final Map<Size, double> _scaleBySize = {};

  Offset? project(double azimuthDegrees, double altitudeDegrees, Size size) {
    return projectVector(
      EnuVector.fromAzimuthAltitude(azimuthDegrees, altitudeDegrees),
      size,
    );
  }

  Offset? projectVector(EnuVector point, Size size) {
    final forwardDistance = _center.dot(point);
    if (forwardDistance <= 0) return null;
    final scale = _scaleBySize.putIfAbsent(
      size,
      () => math.min(size.width, size.height) * 0.46 / _tanHalfFieldOfView,
    );
    final x = point.dot(_right) / forwardDistance * scale;
    final y = -point.dot(_up) / forwardDistance * scale;
    if (!x.isFinite || !y.isFinite) return null;
    return Offset(size.width / 2 + x, size.height / 2 + y);
  }

  static EnuVector _makeRight(double azimuthDegrees) {
    final az = azimuthDegrees * math.pi / 180;
    return EnuVector(math.cos(az), -math.sin(az), 0);
  }

  static EnuVector _makeUp(double azimuthDegrees, double altitudeDegrees) {
    final az = azimuthDegrees * math.pi / 180;
    final alt = altitudeDegrees * math.pi / 180;
    return EnuVector(
      -math.sin(az) * math.sin(alt),
      -math.cos(az) * math.sin(alt),
      math.cos(alt),
    );
  }
}
