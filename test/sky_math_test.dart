import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sky/core/math/sky_math.dart';

void main() {
  group('ENU sky directions', () {
    test('uses azimuth clockwise from north', () {
      final north = EnuVector.fromAzimuthAltitude(0, 0);
      final east = EnuVector.fromAzimuthAltitude(90, 0);
      final zenith = EnuVector.fromAzimuthAltitude(123, 90);

      expect(north.north, closeTo(1, 1e-12));
      expect(east.east, closeTo(1, 1e-12));
      expect(zenith.up, closeTo(1, 1e-12));
    });

    test('uses actual 3D angular separation near azimuth wraparound', () {
      final target = EnuVector.fromAzimuthAltitude(1, 0);
      final forward = EnuVector.fromAzimuthAltitude(359, 0);
      final screenRight = EnuVector(1, 0, 0);
      final result = calculateAlignment(
        target: target,
        cameraForward: forward,
        screenRight: screenRight,
        screenUp: const EnuVector(0, 0, 1),
        toleranceDegrees: 3,
      );

      expect(result.angularSeparationDegrees, closeTo(2, 1e-8));
      expect(result.horizontalErrorDegrees, greaterThan(0));
      expect(result.isAligned, isTrue);
    });

    test('separates horizontal and vertical pointing errors', () {
      final target = EnuVector.fromAzimuthAltitude(90, 30);
      final result = calculateAlignment(
        target: target,
        cameraForward: EnuVector.fromAzimuthAltitude(90, 20),
        screenRight: const EnuVector(0, -1, 0),
        screenUp: const EnuVector(0, 0, 1),
      );

      expect(result.angularSeparationDegrees, closeTo(10, 1e-8));
      expect(result.horizontalErrorDegrees, closeTo(0, 1e-8));
      expect(result.verticalErrorDegrees, greaterThan(0));
      expect(result.isAligned, isFalse);
    });
  });
}
