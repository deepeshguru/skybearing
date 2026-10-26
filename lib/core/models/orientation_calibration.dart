import 'dart:math' as math;

import 'device_orientation.dart';
import '../math/sky_math.dart';

/// Small user-adjustable corrections for compass and tilt sensor alignment.
///
/// Magnetic interference can shift a phone's reported heading without the
/// sensor reporting poor calibration. These offsets let the user align the
/// pointing guide with a known direction on their device.
class OrientationCalibration {
  const OrientationCalibration({
    this.headingOffsetDegrees = 0,
    this.pitchOffsetDegrees = 0,
  });

  final double headingOffsetDegrees;
  final double pitchOffsetDegrees;

  OrientationCalibration copyWith({
    double? headingOffsetDegrees,
    double? pitchOffsetDegrees,
  }) => OrientationCalibration(
    headingOffsetDegrees: headingOffsetDegrees ?? this.headingOffsetDegrees,
    pitchOffsetDegrees: pitchOffsetDegrees ?? this.pitchOffsetDegrees,
  );

  DeviceOrientation apply(DeviceOrientation orientation) {
    if (!orientation.isAvailable ||
        (headingOffsetDegrees == 0 && pitchOffsetDegrees == 0)) {
      return orientation;
    }

    final headingRadians = headingOffsetDegrees * math.pi / 180;
    final pitchedRight = _rotateClockwiseAroundUp(
      orientation.screenRight,
      headingRadians,
    );
    final pitchRadians = pitchOffsetDegrees * math.pi / 180;
    final forward = _rotateAroundAxis(
      _rotateClockwiseAroundUp(orientation.cameraForward, headingRadians),
      pitchedRight,
      pitchRadians,
    );
    final up = _rotateAroundAxis(
      _rotateClockwiseAroundUp(orientation.screenUp, headingRadians),
      pitchedRight,
      pitchRadians,
    );

    return DeviceOrientation(
      cameraForward: forward.normalized(),
      screenRight: pitchedRight.normalized(),
      screenUp: up.normalized(),
      northReference: orientation.northReference,
      quality: orientation.quality,
      timestamp: orientation.timestamp,
      headingAccuracyDegrees: orientation.headingAccuracyDegrees,
    );
  }
}

EnuVector _rotateClockwiseAroundUp(EnuVector vector, double radians) {
  final cosine = math.cos(radians);
  final sine = math.sin(radians);
  return EnuVector(
    vector.east * cosine + vector.north * sine,
    vector.north * cosine - vector.east * sine,
    vector.up,
  );
}

EnuVector _rotateAroundAxis(EnuVector vector, EnuVector axis, double radians) {
  final unitAxis = axis.normalized();
  final cosine = math.cos(radians);
  final sine = math.sin(radians);
  final cross = EnuVector(
    unitAxis.north * vector.up - unitAxis.up * vector.north,
    unitAxis.up * vector.east - unitAxis.east * vector.up,
    unitAxis.east * vector.north - unitAxis.north * vector.east,
  );
  return vector * cosine +
      cross * sine +
      unitAxis * (unitAxis.dot(vector) * (1 - cosine));
}
