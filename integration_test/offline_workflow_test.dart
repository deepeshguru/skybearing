import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offline_sky/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'manual location, bundled search, and calculated details work offline',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      app.main();

      await _pumpUntil(tester, find.text('Look up'));
      await tester.tap(find.text('Settings').last);
      await _pumpUntil(tester, find.text('Edit manually'));
      await tester.tap(find.text('Edit manually'));
      await tester.pump(const Duration(milliseconds: 450));

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), '32.7767');
      await tester.enterText(fields.at(1), '-96.7970');
      await tester.enterText(fields.at(2), '140');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.text('Save manual location'));
      await tester.tap(find.text('Save manual location'));

      await _pumpUntil(tester, find.textContaining('32.7767°'));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.tap(find.text('Discover').last);
      await _pumpUntil(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Jupiter');
      await _pumpUntil(tester, find.textContaining('OFFLINE RESULTS FOR'));
      expect(find.textContaining('OFFLINE RESULTS FOR'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 250));

      final jupiterResult = find.text('Planet · solar:jupiter');
      await _pumpUntil(tester, jupiterResult);
      await tester.ensureVisible(jupiterResult);
      await tester.tap(jupiterResult);
      await _pumpUntil(tester, find.text('Object details'));
      expect(find.text('AZIMUTH'), findsOneWidget);
      expect(find.text('ALTITUDE'), findsOneWidget);
    },
  );
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 200));
  }
  final visibleText = tester.allWidgets
      .whereType<Text>()
      .map((widget) => widget.data)
      .whereType<String>()
      .toSet()
      .join(' | ');
  tester.printToConsole('Timed out waiting for $finder. Text: $visibleText');
  expect(finder, findsOneWidget);
}
