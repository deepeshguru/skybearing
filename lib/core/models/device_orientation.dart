import '../math/sky_math.dart';

enum NorthReference { trueNorth, magneticNorth, unavailable }

enum OrientationQuality { high, medium, low, unavailable }

class DeviceOrientation {
  const DeviceOrientation({
    required this.cameraForward,
    required this.screenRight,
    required this.screenUp,
    required this.northReference,
    required this.quality,
    required this.timestamp,
    this.headingAccuracyDegrees,
  });

  final EnuVector cameraForward;
  final EnuVector screenRight;
  final EnuVector screenUp;
  final NorthReference northReference;
  final OrientationQuality quality;
  final DateTime timestamp;
  final double? headingAccuracyDegrees;

  bool get isAvailable => quality != OrientationQuality.unavailable;
}
