import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offline_sky/app/offline_sky_app.dart';
import 'package:offline_sky/app/providers.dart';

import 'package:offline_sky/core/location/observer_location_store.dart';
import 'package:offline_sky/core/models/observer_location.dart';
import 'package:offline_sky/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'legacy location migrates through Android preferences to app support',
    (tester) async {
      app.main();
      await _pumpUntil(tester, find.text('Look up'));
      final appContext = tester.element(find.byType(OfflineSkyApp));
      final container = ProviderScope.containerOf(appContext, listen: false);
      await _pumpUntilRestored(tester, container);

      final preferences = await SharedPreferences.getInstance();
      final location = ObserverLocation(
        latitudeDegrees: 37.4219983,
        longitudeDegrees: -122.084,
        elevationMeters: 5,
        horizontalAccuracyMeters: 3.3,
        source: LocationSource.gps,
        recordedAt: DateTime.utc(2026, 10, 25, 10, 30),
      );
      await preferences.setString(
        FileObserverLocationStore.legacyPreferenceKey,
        jsonEncode(location.toJson()),
      );

      final store = FileObserverLocationStore.platform();
      final restored = await store.restoreAndMigrate(preferences);
      final supportDirectory = await getApplicationSupportDirectory();
      final locationFile = File(
        path.join(
          supportDirectory.path,
          FileObserverLocationStore.directoryName,
          FileObserverLocationStore.fileName,
        ),
      );

      expect(restored?.latitudeDegrees, location.latitudeDegrees);
      expect(restored?.longitudeDegrees, location.longitudeDegrees);
      expect(await locationFile.exists(), isTrue);
      expect(await File('${locationFile.path}.tmp').exists(), isFalse);
      expect(
        preferences.get(FileObserverLocationStore.legacyPreferenceKey),
        isNull,
      );
    },
  );
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('Timed out waiting for $finder.');
}

Future<void> _pumpUntilRestored(
  WidgetTester tester,
  ProviderContainer container,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (!container.read(skyStateProvider).isRestoring) return;
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('Sky state did not finish restoring.');
}
