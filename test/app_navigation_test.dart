import 'package:astro_engine/astro_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offline_sky/app/offline_sky_app.dart';
import 'package:offline_sky/app/providers.dart';
import 'package:offline_sky/core/astronomy/sky_snapshot.dart';
import 'package:offline_sky/core/database/catalog_repository.dart';
import 'package:offline_sky/core/location/observer_location_store.dart';
import 'package:offline_sky/core/models/celestial_object.dart';
import 'package:offline_sky/core/models/device_orientation.dart';
import 'package:offline_sky/core/models/observer_location.dart';
import 'package:offline_sky/core/math/sky_math.dart';
import 'package:offline_sky/core/models/celestial_target.dart';
import 'package:offline_sky/features/object_locator/locator_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'shows an honest empty sky without a location and navigates tabs',
    (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Look up'), findsOneWidget);
      expect(
        find.text('Choose a location to calculate the sky'),
        findsOneWidget,
      );
      expect(
        find.text('No example or simulated sky positions are shown.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(find.text('Solar System'), findsOneWidget);

      await tester.tap(find.text('Saved').last);
      await tester.pumpAndSettle();
      expect(find.text('No saved objects yet'), findsOneWidget);

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Observer location'), findsOneWidget);
    },
  );

  testWidgets('searches a local catalog record by name', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sirius');
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(find.text('Sirius'), findsNWidgets(2));
    expect(find.text('Star · star:hip:32349'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsOneWidget);

    final resultCard = find
        .ancestor(
          of: find.text('Star · star:hip:32349'),
          matching: find.byType(Card),
        )
        .first;
    final cardRect = tester.getRect(resultCard);
    expect(cardRect.left, closeTo(18, 0.1));
    expect(cardRect.right, closeTo(372, 0.1));
  });

  testWidgets('solar system tiles reflow on narrow phones', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();

    final mercuryTile = find
        .ancestor(of: find.text('Mercury'), matching: find.byType(Card))
        .first;
    expect(tester.getSize(mercuryTile).width, greaterThan(250));
    expect(tester.getSize(mercuryTile).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('main tabs fit representative phone and landscape viewports', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.platformDispatcher.clearTextScaleFactorTestValue);

    for (final size in const [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
      Size(800, 390),
    ]) {
      tester.view.physicalSize = size;
      tester.view.platformDispatcher.textScaleFactorTestValue =
          size.width == 320 ? 1.4 : 1.0;
      await tester.pumpWidget(_testApp(skySnapshot: _emptySkySnapshot()));
      await tester.pumpAndSettle();

      expect(find.text('Look up'), findsOneWidget, reason: '$size sky tab');
      expect(tester.takeException(), isNull, reason: '$size sky tab');

      for (final tab in ['Discover', 'Saved', 'Settings', 'Sky']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size $tab tab');
      }
    }
  });

  testWidgets(
    'location editor remains reachable with keyboard and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.platformDispatcher.textScaleFactorTestValue = 1.35;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit observer location'));
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '32.7767');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save manual location'));
      await tester.pumpAndSettle();

      final saveButton = tester.getRect(find.text('Save manual location'));
      expect(saveButton.bottom, lessThanOrEqualTo(308));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sky map navigation meets accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_testApp(skySnapshot: _emptySkySnapshot()));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('locator guide scrolls and remains labeled on short screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_locatorTestApp(textScale: 1.4));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'Direction guide for Jupiter. Phone orientation is unavailable.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(640, 360);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('sky map zoom controls expose names and 48-pixel targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_testApp(skySnapshot: _emptySkySnapshot()));
      await tester.pumpAndSettle();

      final zoomOut = find.byTooltip('Zoom out');
      final zoomIn = find.byTooltip('Zoom in');
      expect(tester.getSemantics(zoomOut).label, 'Zoom out');
      expect(tester.getSemantics(zoomIn).label, 'Zoom in');
      expect(tester.getSize(zoomOut), const Size(48, 48));
      expect(tester.getSize(zoomIn), const Size(48, 48));
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);

      await tester.tap(zoomOut);
      await tester.pumpAndSettle();
      expect(find.text('86° field · geometric sky'), findsOneWidget);

      await tester.tap(zoomIn);
      await tester.pumpAndSettle();
      expect(find.text('75° field · geometric sky'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'sky map retains pan, follow, and persisted observation-time controls',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          skySnapshot: _locatedSkySnapshot(),
          includeLocation: true,
          orientationAvailable: true,
        ),
      );
      await tester.pumpAndSettle();

      final canvas = find.byType(CustomPaint).first;
      await tester.drag(canvas, const Offset(24, -18));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Follow phone orientation'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.explore), findsOneWidget);
      await tester.tap(find.byTooltip('Follow phone orientation'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);

      await tester.tap(find.byTooltip('Change observation time'));
      await tester.pumpAndSettle();
      expect(find.text('Choose observation date'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Choose local time'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Now'), findsOneWidget);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('selected_time_utc_ms'), isNotNull);
      await tester.pumpWidget(
        _testApp(
          key: const ValueKey('restored-app'),
          skySnapshot: _emptySkySnapshot(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('TIME TRAVEL'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);

      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();
      expect(find.text('Now'), findsNothing);
      expect(preferences.getInt('selected_time_utc_ms'), isNull);
    },
  );

  testWidgets('search, favorite, details, and locator workflow still works', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(skySnapshot: _locatedSkySnapshot(), includeLocation: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jupiter');
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planet · solar:jupiter'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save favorite'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    final findAction = find.text('Find in sky', skipOffstage: false);
    await tester.scrollUntilVisible(
      findAction,
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find in sky'));
    await tester.pumpAndSettle();
    expect(find.text('Find Jupiter'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Object details'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Jupiter'), findsOneWidget);
  });

  testWidgets('sky map controls do not overlap below 164-pixel map width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(180, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(skySnapshot: _emptySkySnapshot(), includeLocation: true),
    );
    await tester.pumpAndSettle();

    final zoomOutRect = tester.getRect(find.byTooltip('Zoom out'));
    final zoomInRect = tester.getRect(find.byTooltip('Zoom in'));
    final followRect = tester.getRect(
      find.byTooltip('Follow phone orientation'),
    );

    expect(zoomOutRect.overlaps(zoomInRect), isFalse);
    expect(zoomOutRect.overlaps(followRect), isFalse);
    expect(zoomInRect.overlaps(followRect), isFalse);
    expect(zoomInRect.top, greaterThan(zoomOutRect.top));
  });
}

Widget _testApp({
  Key? key,
  SkySnapshot? skySnapshot,
  bool includeLocation = false,
  bool orientationAvailable = false,
}) => ProviderScope(
  key: key,
  overrides: [
    observerLocationStoreProvider.overrideWithValue(
      _MemoryObserverLocationStore(),
    ),
    catalogRepositoryProvider.overrideWith((ref) async => _FakeCatalogStore()),
    skySnapshotProvider.overrideWith((ref) async => skySnapshot),
    if (includeLocation)
      skyStateProvider.overrideWith(_LocatedTestSkyController.new),
    orientationProvider.overrideWith(
      (ref) => Stream.value(
        DeviceOrientation(
          cameraForward: const EnuVector(0, 0, 1),
          screenRight: const EnuVector(1, 0, 0),
          screenUp: const EnuVector(0, 1, 0),
          northReference: orientationAvailable
              ? NorthReference.trueNorth
              : NorthReference.unavailable,
          quality: orientationAvailable
              ? OrientationQuality.high
              : OrientationQuality.unavailable,
          timestamp: DateTime.utc(2026),
        ),
      ),
    ),
  ],
  child: const OfflineSkyApp(),
);

Widget _locatorTestApp({double textScale = 1}) {
  final unavailableOrientation = DeviceOrientation(
    cameraForward: const EnuVector(0, 0, 1),
    screenRight: const EnuVector(1, 0, 0),
    screenUp: const EnuVector(0, 1, 0),
    northReference: NorthReference.unavailable,
    quality: OrientationQuality.unavailable,
    timestamp: DateTime.utc(2026),
  );
  final snapshot = SkySnapshot(
    utc: DateTime.utc(2026),
    location: ObserverLocation.manual(
      latitudeDegrees: 0,
      longitudeDegrees: 0,
      elevationMeters: 0,
    ),
    catalogPoints: const [],
    solarPoints: [
      SolarMapPoint(
        SolarBody.jupiter,
        const NativeSkyPosition(
          rightAscensionHours: 0,
          declinationDegrees: 0,
          azimuthDegrees: 180,
          altitudeDegrees: 30,
        ),
      ),
    ],
    constellations: const [],
    segments: const [],
    constellationPaths: const [],
    constellationLabels: const [],
    milkyWayCurves: const [],
  );
  return ProviderScope(
    overrides: [
      skySnapshotProvider.overrideWith((ref) async => snapshot),
      orientationProvider.overrideWith(
        (ref) => Stream.value(unavailableOrientation),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const LocatorScreen(
        target: CelestialTarget.solar(SolarBody.jupiter),
      ),
    ),
  );
}

class _MemoryObserverLocationStore implements ObserverLocationStore {
  ObserverLocation? _location;

  @override
  Future<ObserverLocation?> load() async => _location;

  @override
  Future<void> save(ObserverLocation location) async {
    _location = location;
  }

  @override
  Future<bool> saveAndRemoveLegacy(
    ObserverLocation location,
    Future<SharedPreferences> Function() loadPreferences,
  ) async {
    await save(location);
    final preferences = await loadPreferences();
    await preferences.remove(FileObserverLocationStore.legacyPreferenceKey);
    return preferences.get(FileObserverLocationStore.legacyPreferenceKey) ==
        null;
  }

  @override
  Future<ObserverLocation?> restoreAndMigrate(
    SharedPreferences preferences,
  ) async => _location == null
      ? null
      : FileObserverLocationStore.asSavedLocation(_location!);
}

class _LocatedTestSkyController extends SkyController {
  @override
  SkyState build() => const SkyState(
    location: ObserverLocation(
      latitudeDegrees: 0,
      longitudeDegrees: 0,
      elevationMeters: 0,
      source: LocationSource.manual,
    ),
    isRestoring: false,
  );
}

SkySnapshot _emptySkySnapshot() => SkySnapshot(
  utc: DateTime.utc(2026),
  location: ObserverLocation.manual(
    latitudeDegrees: 0,
    longitudeDegrees: 0,
    elevationMeters: 0,
  ),
  catalogPoints: const [],
  solarPoints: const [],
  constellations: const [],
  segments: const [],
  constellationPaths: const [],
  constellationLabels: const [],
  milkyWayCurves: const [],
);

SkySnapshot _locatedSkySnapshot() => SkySnapshot(
  utc: DateTime.utc(2026),
  location: ObserverLocation.manual(
    latitudeDegrees: 0,
    longitudeDegrees: 0,
    elevationMeters: 0,
  ),
  catalogPoints: const [],
  solarPoints: [
    SolarMapPoint(
      SolarBody.jupiter,
      const NativeSkyPosition(
        rightAscensionHours: 0,
        declinationDegrees: 0,
        azimuthDegrees: 180,
        altitudeDegrees: 30,
      ),
    ),
  ],
  constellations: const [],
  segments: const [],
  constellationPaths: const [],
  constellationLabels: const [],
  milkyWayCurves: const [],
);

class _FakeCatalogStore implements CatalogStore {
  static const _sirius = CelestialObject(
    id: 'star:hip:32349',
    name: 'Sirius',
    type: CelestialType.star,
    rightAscensionHoursJ2000: 6.752481,
    declinationDegreesJ2000: -16.716116,
    epoch: 2000,
    properMotionRaMasPerYear: -546.01,
    properMotionDecMasPerYear: -1223.07,
    magnitude: -1.44,
    magnitudeBand: 'V',
    distanceLightYears: 8.6,
    constellation: 'CMa',
    description: 'Bright star record from the local test catalog.',
    aliases: ['Alpha Canis Majoris', 'Dog Star'],
    source: 'HYG Database v4.1',
  );

  @override
  Future<void> close() async {}

  @override
  Future<CelestialObject?> getById(String id) async =>
      id == _sirius.id ? _sirius : null;

  @override
  Future<List<CelestialObject>> loadDeepSkyObjects() async => const [];

  @override
  Future<List<CelestialObject>> loadNotableObjects() async => const [];

  @override
  Future<List<CelestialObject>> loadStars() async => const [_sirius];

  @override
  Future<List<Constellation>> loadConstellations() async => const [];

  @override
  Future<List<ConstellationSegment>> loadConstellationSegments() async =>
      const [];

  @override
  Future<List<CelestialObject>> search(String query, {int limit = 60}) async =>
      _sirius.name.toLowerCase().contains(query.toLowerCase())
      ? const [_sirius]
      : const [];
}
