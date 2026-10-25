import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android backup rules exclude locations and reproducible catalog files',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final legacyRules = File('android/app/src/main/res/xml/backup_rules.xml')
          .readAsStringSync();
      final extractionRules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:allowBackup="true"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(
        legacyRules,
        contains('<exclude domain="file" path="offline_sky/"'),
      );

      const reproducibleRootPaths = <String>[
        'sky_catalog.sqlite',
        'sky_catalog.sqlite.revision',
        'sky_catalog.sqlite.install.lock',
        'sky_catalog.sqlite.installing',
        'sky_catalog.sqlite.revision.installing',
        'flutter_assets/',
      ];
      for (final relativePath in reproducibleRootPaths) {
        final rule = '<exclude domain="root" path="app_flutter/$relativePath"';
        expect(legacyRules, contains(rule));
      }

      final cloudRules = extractionRules.split('<device-transfer>').first;
      final transferRules = extractionRules.split('<device-transfer>').last;
      expect(
        cloudRules,
        contains('<exclude domain="file" path="offline_sky/"'),
      );
      for (final relativePath in reproducibleRootPaths) {
        final rule = '<exclude domain="root" path="app_flutter/$relativePath"';
        expect(cloudRules, contains(rule));
      }
      expect(
        transferRules,
        contains('<exclude domain="file" path="offline_sky/"'),
      );
      for (final relativePath in reproducibleRootPaths) {
        final rule = '<exclude domain="root" path="app_flutter/$relativePath"';
        expect(transferRules, contains(rule));
      }
      expect(extractionRules, isNot(contains('domain="sharedpref"')));
    },
  );
}
