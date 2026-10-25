import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offline_sky/app/providers.dart';
import 'package:offline_sky/core/location/location_service.dart';
import 'package:offline_sky/core/location/observer_location_store.dart';
import 'package:offline_sky/core/models/observer_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDirectory;
  late FileObserverLocationStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDirectory = await Directory.systemTemp.createTemp(
      'offline-sky-location-test-',
    );
    store = _createStore(supportDirectory);
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('first launch has no observer location', () async {
    final preferences = await SharedPreferences.getInstance();

    expect(await store.restoreAndMigrate(preferences), isNull);
    expect(await store.load(), isNull);
  });

  test(
    'migrates the existing location and preserves other preferences',
    () async {
      final original = _gpsLocation();
      SharedPreferences.setMockInitialValues({
        'observer_location': jsonEncode(original.toJson()),
        'favorites': ['M31', 'star:hip:32349'],
        'selected_time_utc_ms': 1792958400000,
        'camera_vertical_fov_degrees': 51.5,
      });
      final preferences = await SharedPreferences.getInstance();

      final restored = await store.restoreAndMigrate(preferences);
      final stored = await store.load();

      expect(restored?.source, LocationSource.saved);
      expect(stored?.latitudeDegrees, original.latitudeDegrees);
      expect(stored?.longitudeDegrees, original.longitudeDegrees);
      expect(stored?.elevationMeters, original.elevationMeters);
      expect(
        stored?.horizontalAccuracyMeters,
        original.horizontalAccuracyMeters,
      );
      expect(stored?.source, LocationSource.gps);
      expect(stored?.recordedAt, original.recordedAt);
      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNull,
      );
      expect(preferences.getStringList('favorites'), ['M31', 'star:hip:32349']);
      expect(preferences.getInt('selected_time_utc_ms'), 1792958400000);
      expect(preferences.getDouble('camera_vertical_fov_degrees'), 51.5);
    },
  );

  test(
    'invalid legacy coordinates are removed without touching preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'observer_location': jsonEncode({
          'latitude': 91,
          'longitude': 20,
          'elevation': 10,
          'accuracy': 4,
          'source': 'gps',
          'recordedAt': 1792958400000,
        }),
        'favorites': ['M31'],
      });
      final preferences = await SharedPreferences.getInstance();

      expect(await store.restoreAndMigrate(preferences), isNull);
      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNull,
      );
      expect(preferences.getStringList('favorites'), ['M31']);
      expect(await store.load(), isNull);
    },
  );

  test(
    'a partially written legacy value does not replace valid local data',
    () async {
      SharedPreferences.setMockInitialValues({
        'observer_location': '{"latitude":',
        'favorites': ['M31'],
      });
      final preferences = await SharedPreferences.getInstance();

      expect(await store.restoreAndMigrate(preferences), isNull);
      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNull,
      );
      expect(preferences.getStringList('favorites'), ['M31']);
    },
  );

  test('interrupted migration keeps the legacy value and can retry', () async {
    final original = _gpsLocation();
    SharedPreferences.setMockInitialValues({
      'observer_location': jsonEncode(original.toJson()),
    });
    final preferences = await SharedPreferences.getInstance();
    var protectCalls = 0;
    var shouldInterrupt = true;
    final interruptingStore = FileObserverLocationStore(
      applicationSupportDirectory: () async => supportDirectory,
      excludeFromBackup: (_) async {
        protectCalls++;
        if (shouldInterrupt && protectCalls == 3) {
          throw StateError('simulated interruption after atomic install');
        }
      },
    );

    await expectLater(
      interruptingStore.restoreAndMigrate(preferences),
      throwsStateError,
    );
    expect(
      preferences.get(FileObserverLocationStore.legacyPreferenceKey),
      isNotNull,
    );
    expect((await interruptingStore.load())?.latitudeDegrees, 32.7767);

    shouldInterrupt = false;
    final restored = await interruptingStore.restoreAndMigrate(preferences);
    expect(restored?.source, LocationSource.saved);
    expect(restored?.latitudeDegrees, original.latitudeDegrees);
    expect(
      preferences.get(FileObserverLocationStore.legacyPreferenceKey),
      isNull,
    );
  });

  test(
    'a later protected manual save removes a legacy backup-eligible copy',
    () async {
      final legacyLocation = _gpsLocation();
      SharedPreferences.setMockInitialValues({
        FileObserverLocationStore.legacyPreferenceKey: jsonEncode(
          legacyLocation.toJson(),
        ),
      });
      final preferences = await SharedPreferences.getInstance();
      var protectionAvailable = false;
      final intermittentlyProtectedStore = FileObserverLocationStore(
        applicationSupportDirectory: () async => supportDirectory,
        excludeFromBackup: (_) async {
          if (!protectionAvailable) {
            throw StateError('simulated backup-exclusion failure');
          }
        },
      );
      final container = ProviderContainer(
        overrides: [
          observerLocationStoreProvider.overrideWithValue(
            intermittentlyProtectedStore,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(skyStateProvider.notifier);
      await _waitForRestore(container);
      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNotNull,
      );
      expect(
        container.read(skyStateProvider).locationMessage,
        contains('may be included in backups'),
      );

      protectionAvailable = true;
      await controller.setManualLocation(
        latitudeDegrees: -33.8688,
        longitudeDegrees: 151.2093,
        elevationMeters: 58,
      );

      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNull,
      );
      expect(
        (await intermittentlyProtectedStore.load())?.latitudeDegrees,
        -33.8688,
      );
      expect(container.read(skyStateProvider).locationMessage, isNull);
    },
  );

  test(
    'failed GPS persistence keeps the legacy backup warning visible',
    () async {
      final legacyLocation = _gpsLocation();
      SharedPreferences.setMockInitialValues({
        FileObserverLocationStore.legacyPreferenceKey: jsonEncode(
          legacyLocation.toJson(),
        ),
      });
      final preferences = await SharedPreferences.getInstance();
      final unavailableStore = FileObserverLocationStore(
        applicationSupportDirectory: () async => supportDirectory,
        excludeFromBackup: (_) async {
          throw StateError('simulated backup-exclusion failure');
        },
      );
      final container = ProviderContainer(
        overrides: [
          observerLocationStoreProvider.overrideWithValue(unavailableStore),
          locationServiceProvider.overrideWithValue(
            _FixedLocationService(_gpsLocation()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(skyStateProvider.notifier);
      await _waitForRestore(container);
      expect(
        container.read(skyStateProvider).locationMessage,
        contains('may be included in backups'),
      );

      await controller.detectLocation();

      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNotNull,
      );
      expect(
        container.read(skyStateProvider).locationMessage,
        allOf(
          contains('Location could not be saved securely'),
          contains('may be included in backups'),
        ),
      );
    },
  );

  test(
    'repeated migration is idempotent and preserves the installed location',
    () async {
      final original = _gpsLocation();
      SharedPreferences.setMockInitialValues({
        'observer_location': jsonEncode(original.toJson()),
        'favorites': ['M31'],
      });
      final preferences = await SharedPreferences.getInstance();

      final first = await store.restoreAndMigrate(preferences);
      final second = await store.restoreAndMigrate(preferences);

      expect(first?.latitudeDegrees, original.latitudeDegrees);
      expect(second?.longitudeDegrees, original.longitudeDegrees);
      expect(second?.source, LocationSource.saved);
      expect(preferences.getStringList('favorites'), ['M31']);
      final stored = await store.load();
      expect(stored?.latitudeDegrees, original.latitudeDegrees);
      expect(stored?.longitudeDegrees, original.longitudeDegrees);
      expect(stored?.source, original.source);
    },
  );

  test(
    'a new store instance can load the saved location after restart',
    () async {
      final original = _gpsLocation();
      await store.save(original);
      final restartedStore = _createStore(supportDirectory);

      final loaded = await restartedStore.load();

      expect(loaded?.latitudeDegrees, original.latitudeDegrees);
      expect(loaded?.longitudeDegrees, original.longitudeDegrees);
      expect(loaded?.elevationMeters, original.elevationMeters);
      expect(
        loaded?.horizontalAccuracyMeters,
        original.horizontalAccuracyMeters,
      );
      expect(loaded?.source, LocationSource.gps);
      expect(loaded?.recordedAt, original.recordedAt);
    },
  );

  test(
    'GPS and manual controller updates use the device-local store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final gpsLocation = _gpsLocation();
      final container = ProviderContainer(
        overrides: [
          observerLocationStoreProvider.overrideWithValue(store),
          locationServiceProvider.overrideWithValue(
            _FixedLocationService(gpsLocation),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(skyStateProvider.notifier);
      await _waitForRestore(container);
      await controller.setManualLocation(
        latitudeDegrees: -33.8688,
        longitudeDegrees: 151.2093,
        elevationMeters: 58,
      );
      expect((await store.load())?.source, LocationSource.manual);
      expect((await store.load())?.latitudeDegrees, -33.8688);

      await controller.detectLocation();
      final storedGps = await store.load();
      expect(storedGps?.source, LocationSource.gps);
      expect(storedGps?.latitudeDegrees, gpsLocation.latitudeDegrees);
      expect(
        storedGps?.horizontalAccuracyMeters,
        gpsLocation.horizontalAccuracyMeters,
      );
      expect(storedGps?.recordedAt, gpsLocation.recordedAt);
      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNull,
      );
    },
  );
}

FileObserverLocationStore _createStore(Directory supportDirectory) =>
    FileObserverLocationStore(
      applicationSupportDirectory: () async => supportDirectory,
      excludeFromBackup: (_) async {},
    );

ObserverLocation _gpsLocation() => ObserverLocation(
  latitudeDegrees: 32.7767,
  longitudeDegrees: -96.7970,
  elevationMeters: 140.5,
  horizontalAccuracyMeters: 8.25,
  source: LocationSource.gps,
  recordedAt: DateTime.utc(2026, 10, 25, 10, 30, 15),
);

Future<void> _waitForRestore(ProviderContainer container) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (!container.read(skyStateProvider).isRestoring) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Sky state did not finish restoring.');
}

class _FixedLocationService extends LocationService {
  _FixedLocationService(this.location);

  final ObserverLocation location;

  @override
  Future<ObserverLocation> currentLocation() async => location;
}
