import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/observer_location.dart';

enum LocationFailureKind {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
  stale,
}

class LocationFailure implements Exception {
  const LocationFailure(this.kind, this.message);
  final LocationFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<ObserverLocation> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        LocationFailureKind.serviceDisabled,
        'Location services are turned off on this device.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureKind.permissionDeniedForever,
        'Location permission is blocked. Enable it in app settings to use GPS.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        LocationFailureKind.permissionDenied,
        'Location permission was denied. Enter a location manually or try again.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      );
      final age = DateTime.now().difference(position.timestamp).abs();
      if (age > const Duration(minutes: 15)) {
        throw const LocationFailure(
          LocationFailureKind.stale,
          'The device returned an old GPS fix. Try again outdoors or use a saved location.',
        );
      }
      return ObserverLocation(
        latitudeDegrees: position.latitude,
        longitudeDegrees: position.longitude,
        elevationMeters: position.altitude.isFinite ? position.altitude : 0,
        horizontalAccuracyMeters: position.accuracy.isFinite
            ? position.accuracy
            : null,
        source: LocationSource.gps,
        recordedAt: position.timestamp.toUtc(),
      );
    } on LocationFailure {
      rethrow;
    } catch (error) {
      throw LocationFailure(
        LocationFailureKind.unavailable,
        'Could not obtain a GPS fix: $error',
      );
    }
  }

  Future<void> openSettings() async {
    if (!await Geolocator.openAppSettings()) {
      throw const LocationFailure(
        LocationFailureKind.unavailable,
        'Unable to open app settings.',
      );
    }
  }

  LocationSettings _locationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Keep the Android implementation on platform location providers so a
      // satellite GNSS fix can be used with the network disabled.
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        forceLocationManager: true,
        timeLimit: const Duration(seconds: 35),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      timeLimit: Duration(seconds: 35),
    );
  }
}
