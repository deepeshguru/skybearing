import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/observer_location.dart';

typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();
typedef LocationBackupExcluder = Future<void> Function(File locationFile);

abstract interface class ObserverLocationStore {
  Future<ObserverLocation?> load();

  Future<void> save(ObserverLocation location);

  /// Saves a new protected location before clearing its old, backup-eligible
  /// preference copy. Returns false if preferences could not be cleaned.
  Future<bool> saveAndRemoveLegacy(
    ObserverLocation location,
    Future<SharedPreferences> Function() loadPreferences,
  );

  Future<ObserverLocation?> restoreAndMigrate(SharedPreferences preferences);
}

/// Stores observer coordinates separately from preferences that are restored
/// onto another device. Android backup rules exclude this directory; iOS marks
/// the directory and file with NSURLIsExcludedFromBackupKey.
class FileObserverLocationStore implements ObserverLocationStore {
  FileObserverLocationStore({
    required this.applicationSupportDirectory,
    required this.excludeFromBackup,
  });

  factory FileObserverLocationStore.platform() => FileObserverLocationStore(
    applicationSupportDirectory: getApplicationSupportDirectory,
    excludeFromBackup: _excludeFromPlatformBackup,
  );

  static const legacyPreferenceKey = 'observer_location';
  static const directoryName = 'offline_sky';
  static const fileName = 'observer_location.json';

  static const _backupChannel = MethodChannel(
    'com.offlinesky.sky/location_backup',
  );

  final ApplicationSupportDirectoryProvider applicationSupportDirectory;
  final LocationBackupExcluder excludeFromBackup;

  Future<void> _operationTail = Future<void>.value();

  static Future<void> _excludeFromPlatformBackup(File locationFile) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _backupChannel.invokeMethod<void>('excludeLocationStore', {
      'path': locationFile.path,
    });
  }

  Future<File> _locationFile() async {
    final supportDirectory = await applicationSupportDirectory();
    final locationDirectory = Directory(
      path.join(supportDirectory.path, directoryName),
    );
    await locationDirectory.create(recursive: true);
    return File(path.join(locationDirectory.path, fileName));
  }

  @override
  Future<ObserverLocation?> load() async {
    final file = await _locationFile();
    await excludeFromBackup(file);
    return _readLocation(file);
  }

  @override
  Future<void> save(ObserverLocation location) =>
      _serialize(() => _saveAtomically(location));

  @override
  Future<bool> saveAndRemoveLegacy(
    ObserverLocation location,
    Future<SharedPreferences> Function() loadPreferences,
  ) => _serialize(() async {
    await _saveAtomically(location);
    try {
      final preferences = await loadPreferences();
      await _removeLegacyLocation(preferences);
      return preferences.get(legacyPreferenceKey) == null;
    } on Object {
      // The protected file is already verified. Keep using it and let startup
      // migration retry cleanup of the old preference later.
      return false;
    }
  });

  Future<void> _saveAtomically(ObserverLocation location) async {
    _validate(location);
    final file = await _locationFile();
    // On iOS this excludes the containing directory before any new data is
    // written. Android additionally excludes the directory in both backup XMLs.
    await excludeFromBackup(file);

    final temporaryFile = File('${file.path}.tmp');
    try {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      await temporaryFile.writeAsString(
        jsonEncode(location.toJson()),
        flush: true,
      );
      final temporaryValue = await _readLocation(temporaryFile);
      if (temporaryValue == null || !_sameLocation(temporaryValue, location)) {
        throw const FormatException(
          'Saved observer location did not validate.',
        );
      }

      // Both files live in the same directory, so the complete temporary file
      // replaces the old location atomically on Android and iOS.
      await temporaryFile.rename(file.path);
      await excludeFromBackup(file);

      final installedValue = await _readLocation(file);
      if (installedValue == null || !_sameLocation(installedValue, location)) {
        throw const FormatException(
          'Installed observer location did not validate.',
        );
      }
    } finally {
      if (await temporaryFile.exists()) await temporaryFile.delete();
    }
  }

  @override
  Future<ObserverLocation?> restoreAndMigrate(SharedPreferences preferences) =>
      _serialize(() => _restoreAndMigrate(preferences));

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final previous = _operationTail;
    final next = Completer<void>();
    _operationTail = next.future;
    return _runAfter(previous, next, operation);
  }

  Future<T> _runAfter<T>(
    Future<void> previous,
    Completer<void> next,
    Future<T> Function() operation,
  ) async {
    try {
      await previous;
      return await operation();
    } finally {
      next.complete();
    }
  }

  Future<ObserverLocation?> _restoreAndMigrate(
    SharedPreferences preferences,
  ) async {
    final savedLocation = await load();
    final legacyValue = preferences.get(legacyPreferenceKey);

    if (savedLocation != null) {
      if (legacyValue != null) await _removeLegacyLocation(preferences);
      return asSavedLocation(savedLocation);
    }

    if (legacyValue == null) return null;
    final legacyLocation = decodeLegacyValue(legacyValue);
    if (legacyLocation == null) {
      await _removeLegacyLocation(preferences);
      return null;
    }

    // Keep the old preference until the new file is written, protected, and
    // read back successfully. A crash or write failure can retry this path.
    await _saveAtomically(legacyLocation);
    final installedLocation = await load();
    if (installedLocation == null ||
        !_sameLocation(installedLocation, legacyLocation)) {
      throw StateError('Observer location migration could not be verified.');
    }

    await _removeLegacyLocation(preferences);
    return asSavedLocation(installedLocation);
  }

  Future<void> _removeLegacyLocation(SharedPreferences preferences) async {
    final removed = await preferences.remove(legacyPreferenceKey);
    if (!removed && preferences.get(legacyPreferenceKey) != null) {
      throw StateError('Legacy observer location could not be removed.');
    }
  }

  static ObserverLocation? decodeLegacyValue(Object? value) {
    if (value is! String) return null;
    return _decode(value);
  }

  static ObserverLocation asSavedLocation(ObserverLocation location) =>
      ObserverLocation(
        latitudeDegrees: location.latitudeDegrees,
        longitudeDegrees: location.longitudeDegrees,
        elevationMeters: location.elevationMeters,
        horizontalAccuracyMeters: location.horizontalAccuracyMeters,
        source: LocationSource.saved,
        recordedAt: location.recordedAt,
      );

  Future<ObserverLocation?> _readLocation(File file) async {
    if (!await file.exists()) return null;
    try {
      return _decode(await file.readAsString());
    } on FileSystemException {
      rethrow;
    } on FormatException {
      return null;
    }
  }

  static ObserverLocation? _decode(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      final location = ObserverLocation.fromJson(
        Map<String, Object?>.from(decoded),
      );
      _validate(location);
      return location;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on RangeError {
      return null;
    }
  }

  static void _validate(ObserverLocation location) {
    if (!location.latitudeDegrees.isFinite ||
        location.latitudeDegrees < -90 ||
        location.latitudeDegrees > 90) {
      throw const FormatException('Observer latitude is invalid.');
    }
    if (!location.longitudeDegrees.isFinite ||
        location.longitudeDegrees < -180 ||
        location.longitudeDegrees > 180) {
      throw const FormatException('Observer longitude is invalid.');
    }
    if (!location.elevationMeters.isFinite) {
      throw const FormatException('Observer elevation is invalid.');
    }
    final accuracy = location.horizontalAccuracyMeters;
    if (accuracy != null && (!accuracy.isFinite || accuracy < 0)) {
      throw const FormatException('Observer location accuracy is invalid.');
    }
  }

  static bool _sameLocation(ObserverLocation left, ObserverLocation right) =>
      left.latitudeDegrees == right.latitudeDegrees &&
      left.longitudeDegrees == right.longitudeDegrees &&
      left.elevationMeters == right.elevationMeters &&
      left.horizontalAccuracyMeters == right.horizontalAccuracyMeters &&
      left.source == right.source &&
      left.recordedAt?.toUtc().millisecondsSinceEpoch ==
          right.recordedAt?.toUtc().millisecondsSinceEpoch;
}
