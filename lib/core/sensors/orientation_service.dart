import 'package:flutter/services.dart' hide DeviceOrientation;

import '../math/sky_math.dart';
import '../models/device_orientation.dart';

class OrientationService {
  OrientationService._();

  static const _methodChannel = MethodChannel('com.offlinesky.sky/orientation');
  static const _eventChannel = EventChannel(
    'com.offlinesky.sky/orientation/events',
  );

  static Stream<DeviceOrientation> watch() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is! Map) return _unavailable();
      final data = Map<Object?, Object?>.from(event);
      if (data['available'] != true) return _unavailable();
      final reference = switch (data['northReference']) {
        'true' => NorthReference.trueNorth,
        'magnetic' => NorthReference.magneticNorth,
        _ => NorthReference.unavailable,
      };
      final quality = switch (data['quality']) {
        'high' => OrientationQuality.high,
        'medium' => OrientationQuality.medium,
        'low' => OrientationQuality.low,
        _ => OrientationQuality.unavailable,
      };
      return DeviceOrientation(
        cameraForward: EnuVector(
          _number(data['cameraEast']),
          _number(data['cameraNorth']),
          _number(data['cameraUp']),
        ).normalized(),
        screenRight: EnuVector(
          _number(data['rightEast']),
          _number(data['rightNorth']),
          _number(data['rightUp']),
        ).normalized(),
        screenUp: EnuVector(
          _number(data['upEast']),
          _number(data['upNorth']),
          _number(data['upUp']),
        ).normalized(),
        northReference: reference,
        quality: quality,
        timestamp: DateTime.now(),
        headingAccuracyDegrees: (data['headingAccuracyDegrees'] as num?)
            ?.toDouble(),
      );
    });
  }

  static Future<void> setObserverLocation({
    required double latitudeDegrees,
    required double longitudeDegrees,
    required double elevationMeters,
  }) async {
    await _methodChannel.invokeMethod<void>('setObserverLocation', {
      'latitude': latitudeDegrees,
      'longitude': longitudeDegrees,
      'elevation': elevationMeters,
    });
  }

  static double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  static DeviceOrientation _unavailable() => DeviceOrientation(
    cameraForward: const EnuVector(0, 0, 1),
    screenRight: const EnuVector(1, 0, 0),
    screenUp: const EnuVector(0, 1, 0),
    northReference: NorthReference.unavailable,
    quality: OrientationQuality.unavailable,
    timestamp: DateTime.now(),
  );
}
