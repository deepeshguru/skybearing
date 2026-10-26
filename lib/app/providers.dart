import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/catalog_repository.dart';
import '../core/location/location_service.dart';
import '../core/location/observer_location_store.dart';
import '../core/models/device_orientation.dart';
import '../core/models/orientation_calibration.dart';
import '../core/models/observer_location.dart';
import '../core/sensors/orientation_service.dart';

const _locationMigrationBackupWarning =
    'Saved coordinates remain in preferences and may be included in backups '
    'until secure migration succeeds.';
const _locationCleanupBackupWarning =
    'The new location is saved on this device, but an older preference copy '
    'may still be included in backups.';

final catalogRepositoryProvider = FutureProvider.autoDispose<CatalogStore>((
  ref,
) async {
  final repository = await CatalogRepository.open();
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
final observerLocationStoreProvider = Provider<ObserverLocationStore>(
  (ref) => FileObserverLocationStore.platform(),
);

final orientationCalibrationProvider =
    NotifierProvider<OrientationCalibrationController, OrientationCalibration>(
      OrientationCalibrationController.new,
    );

final orientationProvider = StreamProvider.autoDispose<DeviceOrientation>((
  ref,
) {
  return OrientationService.watch().map(
    (orientation) =>
        ref.read(orientationCalibrationProvider).apply(orientation),
  );
});

class OrientationCalibrationController
    extends Notifier<OrientationCalibration> {
  static const _headingKey = 'orientation_heading_offset_degrees';
  static const _pitchKey = 'orientation_pitch_offset_degrees';

  int _revision = 0;

  @override
  OrientationCalibration build() {
    unawaited(_restore());
    return const OrientationCalibration();
  }

  Future<void> _restore() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    final heading = preferences.getDouble(_headingKey) ?? 0;
    final pitch = preferences.getDouble(_pitchKey) ?? 0;
    state = OrientationCalibration(
      headingOffsetDegrees: heading.isFinite
          ? heading.clamp(-30, 30).toDouble()
          : 0,
      pitchOffsetDegrees: pitch.isFinite ? pitch.clamp(-15, 15).toDouble() : 0,
    );
  }

  void setHeadingOffset(double degrees) {
    _revision++;
    state = state.copyWith(
      headingOffsetDegrees: degrees.clamp(-30, 30).toDouble(),
    );
  }

  void setPitchOffset(double degrees) {
    _revision++;
    state = state.copyWith(
      pitchOffsetDegrees: degrees.clamp(-15, 15).toDouble(),
    );
  }

  Future<void> save() async {
    final calibration = state;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_headingKey, calibration.headingOffsetDegrees);
    await preferences.setDouble(_pitchKey, calibration.pitchOffsetDegrees);
  }

  Future<void> reset() async {
    _revision++;
    state = const OrientationCalibration();
    await save();
  }
}

final skyStateProvider = NotifierProvider<SkyController, SkyState>(
  SkyController.new,
);
final cameraVerticalFovProvider =
    NotifierProvider<CameraVerticalFovController, double>(
      CameraVerticalFovController.new,
    );

class CameraVerticalFovController extends Notifier<double> {
  @override
  double build() {
    unawaited(_restore());
    return 45;
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getDouble('camera_vertical_fov_degrees');
    if (value != null && value.isFinite && value >= 35 && value <= 70) {
      state = value;
    }
  }

  Future<void> setDegrees(double value) async {
    state = value.clamp(35, 70).toDouble();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('camera_vertical_fov_degrees', state);
  }
}

class SkyState {
  const SkyState({
    this.location,
    this.isRestoring = true,
    this.isLocating = false,
    this.locationMessage,
    this.liveTime = true,
    this.selectedUtc,
    this.clockTick,
    this.favorites = const {},
  });

  final ObserverLocation? location;
  final bool isRestoring;
  final bool isLocating;
  final String? locationMessage;
  final bool liveTime;
  final DateTime? selectedUtc;
  final DateTime? clockTick;
  final Set<String> favorites;

  DateTime get currentTime =>
      liveTime ? clockTick ?? DateTime.now() : selectedUtc ?? DateTime.now();

  SkyState copyWith({
    ObserverLocation? location,
    bool clearLocation = false,
    bool? isRestoring,
    bool? isLocating,
    String? locationMessage,
    bool clearLocationMessage = false,
    bool? liveTime,
    DateTime? selectedUtc,
    bool clearSelectedUtc = false,
    DateTime? clockTick,
    Set<String>? favorites,
  }) {
    return SkyState(
      location: clearLocation ? null : location ?? this.location,
      isRestoring: isRestoring ?? this.isRestoring,
      isLocating: isLocating ?? this.isLocating,
      locationMessage: clearLocationMessage
          ? null
          : locationMessage ?? this.locationMessage,
      liveTime: liveTime ?? this.liveTime,
      selectedUtc: clearSelectedUtc ? null : selectedUtc ?? this.selectedUtc,
      clockTick: clockTick ?? this.clockTick,
      favorites: favorites ?? this.favorites,
    );
  }
}

class SkyController extends Notifier<SkyState> {
  @override
  SkyState build() {
    unawaited(_restore());
    return const SkyState();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    ObserverLocation? location;
    String? locationMessage;
    final locationStore = ref.read(observerLocationStoreProvider);
    try {
      location = await locationStore.restoreAndMigrate(preferences);
    } on Object {
      // Continue showing a valid legacy location if the device-local write or
      // backup-exclusion check is temporarily unavailable. The preference is
      // left intact and migration is retried on the next restore.
      locationMessage = _locationMigrationBackupWarning;
      try {
        location = await locationStore.load();
      } on Object {
        location = null;
      }
      location ??= FileObserverLocationStore.decodeLegacyValue(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
      );
      if (location != null) {
        location = FileObserverLocationStore.asSavedLocation(location);
      }
    }
    final epoch = preferences.getInt('selected_time_utc_ms');
    final favorites =
        preferences.getStringList('favorites')?.toSet() ?? <String>{};
    state = state.copyWith(
      location: location,
      locationMessage: locationMessage,
      isRestoring: false,
      selectedUtc: epoch == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true),
      liveTime: epoch == null,
      favorites: favorites,
    );
    if (location != null) _updateNativeLocation(location);
  }

  Future<void> detectLocation() async {
    state = state.copyWith(isLocating: true);
    late final ObserverLocation location;
    try {
      location = await ref.read(locationServiceProvider).currentLocation();
    } on LocationFailure catch (error) {
      state = state.copyWith(
        isLocating: false,
        locationMessage: _preserveBackupWarning(error.message),
      );
      return;
    } catch (error) {
      state = state.copyWith(
        isLocating: false,
        locationMessage: _preserveBackupWarning(
          'Location could not be read: $error',
        ),
      );
      return;
    }

    try {
      final legacyRemoved = await _storeLocation(location);
      state = state.copyWith(
        location: location,
        isLocating: false,
        locationMessage: legacyRemoved ? null : _locationCleanupBackupWarning,
        clearLocationMessage: legacyRemoved,
      );
    } catch (error) {
      state = state.copyWith(
        isLocating: false,
        locationMessage: _preserveBackupWarning(
          'Location could not be saved securely: $error',
        ),
      );
    }
  }

  String _preserveBackupWarning(String message) {
    final previousMessage = state.locationMessage;
    if (previousMessage == null ||
        !previousMessage.contains('may be included in backups')) {
      return message;
    }
    return '$message\n$previousMessage';
  }

  Future<void> setManualLocation({
    required double latitudeDegrees,
    required double longitudeDegrees,
    required double elevationMeters,
  }) async {
    if (!latitudeDegrees.isFinite ||
        latitudeDegrees < -90 ||
        latitudeDegrees > 90) {
      throw const FormatException(
        'Latitude must be between -90 and 90 degrees.',
      );
    }
    if (!longitudeDegrees.isFinite ||
        longitudeDegrees < -180 ||
        longitudeDegrees > 180) {
      throw const FormatException(
        'Longitude must be between -180 and 180 degrees.',
      );
    }
    if (!elevationMeters.isFinite ||
        elevationMeters < -500 ||
        elevationMeters > 100000) {
      throw const FormatException(
        'Elevation must be between -500 and 100000 meters.',
      );
    }
    final location = ObserverLocation.manual(
      latitudeDegrees: latitudeDegrees,
      longitudeDegrees: longitudeDegrees,
      elevationMeters: elevationMeters,
    );
    final legacyRemoved = await _storeLocation(location);
    state = state.copyWith(
      location: location,
      locationMessage: legacyRemoved ? null : _locationCleanupBackupWarning,
      clearLocationMessage: legacyRemoved,
    );
  }

  Future<bool> _storeLocation(ObserverLocation location) async {
    final legacyRemoved = await ref
        .read(observerLocationStoreProvider)
        .saveAndRemoveLegacy(location, SharedPreferences.getInstance);
    _updateNativeLocation(location);
    return legacyRemoved;
  }

  void _updateNativeLocation(ObserverLocation location) {
    unawaited(
      OrientationService.setObserverLocation(
        latitudeDegrees: location.latitudeDegrees,
        longitudeDegrees: location.longitudeDegrees,
        elevationMeters: location.elevationMeters,
      ).catchError((_) {}),
    );
  }

  Future<void> setSelectedTime(DateTime localTime) async {
    final utc = localTime.toUtc();
    state = state.copyWith(liveTime: false, selectedUtc: utc);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      'selected_time_utc_ms',
      utc.millisecondsSinceEpoch,
    );
  }

  Future<void> setNow() async {
    state = state.copyWith(
      liveTime: true,
      clearSelectedUtc: true,
      clockTick: DateTime.now(),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('selected_time_utc_ms');
  }

  void tickClock() {
    if (state.liveTime) state = state.copyWith(clockTick: DateTime.now());
  }

  Future<void> toggleFavorite(String id) async {
    final favorites = {...state.favorites};
    if (!favorites.add(id)) favorites.remove(id);
    state = state.copyWith(favorites: favorites);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'favorites',
      favorites.toList(growable: false),
    );
  }
}
