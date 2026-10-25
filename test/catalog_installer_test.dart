import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sky/core/database/catalog_installer.dart';

void main() {
  late Directory directory;
  late String databasePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('offline-sky-catalog-');
    databasePath = '${directory.path}/sky_catalog.sqlite';
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'retries after an interrupted first copy and removes the partial file',
    () async {
      var failFirstCopy = true;
      final installer = _installer(
        write: (destination) async {
          if (failFirstCopy) {
            await destination.writeAsString('partial');
            failFirstCopy = false;
            throw const FileSystemException('simulated disk full');
          }
          await destination.writeAsString('valid catalog');
        },
      );

      await expectLater(
        installer.ensureInstalled(databasePath),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(databasePath).exists(), isFalse);
      expect(await File('$databasePath.installing').exists(), isFalse);

      await installer.ensureInstalled(databasePath);

      expect(await File(databasePath).readAsString(), 'valid catalog');
      expect(await File('$databasePath.revision').readAsString(), '1\n');
    },
  );

  test(
    'replaces a corrupt installation only after the bundled copy validates',
    () async {
      await File(databasePath).writeAsString('corrupt');
      await File('$databasePath.revision').writeAsString('1\n');
      var writes = 0;
      final installer = _installer(
        write: (destination) async {
          writes++;
          await destination.writeAsString('valid catalog');
        },
      );

      await installer.ensureInstalled(databasePath);

      expect(writes, 1);
      expect(await File(databasePath).readAsString(), 'valid catalog');
      await installer.ensureInstalled(databasePath);
      expect(writes, 1);
    },
  );

  test(
    'preserves a valid catalog and avoids recopying on repeated initialization',
    () async {
      var writes = 0;
      final installer = _installer(
        write: (destination) async {
          writes++;
          await destination.writeAsString('valid catalog');
        },
      );

      await installer.ensureInstalled(databasePath);
      await installer.ensureInstalled(databasePath);

      expect(writes, 1);
      expect(await File(databasePath).readAsString(), 'valid catalog');
    },
  );

  test('keeps a valid unmarked catalog from an older app version', () async {
    await File(databasePath).writeAsString('valid catalog');
    var writes = 0;
    final installer = _installer(
      write: (destination) async {
        writes++;
        await destination.writeAsString('new bundled catalog');
      },
    );

    await installer.ensureInstalled(databasePath);

    expect(writes, 0);
    expect(await File(databasePath).readAsString(), 'valid catalog');
    expect(await File('$databasePath.revision').readAsString(), '1\n');
  });

  test('serializes concurrent initialization and installs once', () async {
    var writes = 0;
    final installer = _installer(
      write: (destination) async {
        writes++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await destination.writeAsString('valid catalog');
      },
    );

    await Future.wait([
      installer.ensureInstalled(databasePath),
      installer.ensureInstalled(databasePath),
    ]);

    expect(writes, 1);
    expect(await File(databasePath).readAsString(), 'valid catalog');
  });

  test(
    'reinstalls a valid catalog when its bundled revision changes',
    () async {
      await File(databasePath).writeAsString('old catalog');
      await File('$databasePath.revision').writeAsString('1\n');
      var writes = 0;
      final installer = _installer(
        revision: 2,
        write: (destination) async {
          writes++;
          await destination.writeAsString('new catalog');
        },
      );

      await installer.ensureInstalled(databasePath);

      expect(writes, 1);
      expect(await File(databasePath).readAsString(), 'new catalog');
      expect(await File('$databasePath.revision').readAsString(), '2\n');
    },
  );

  test(
    'keeps the previous catalog when a replacement copy is corrupt',
    () async {
      await File(databasePath).writeAsString('old valid catalog');
      await File('$databasePath.revision').writeAsString('1\n');
      final installer = CatalogInstaller(
        catalogRevision: 2,
        writeBundledCatalog: (destination) async {
          await destination.writeAsString('bad bundled catalog');
        },
        validateCatalog: (file) async {
          if (await file.readAsString() != 'old valid catalog') {
            throw const CatalogValidationException();
          }
        },
      );

      await expectLater(
        installer.ensureInstalled(databasePath),
        throwsA(isA<CatalogValidationException>()),
      );

      expect(await File(databasePath).readAsString(), 'old valid catalog');
      expect(await File('$databasePath.revision').readAsString(), '1\n');
      expect(await File('$databasePath.installing').exists(), isFalse);
    },
  );
}

CatalogInstaller _installer({
  required CatalogFileWriter write,
  int revision = 1,
}) => CatalogInstaller(
  catalogRevision: revision,
  writeBundledCatalog: write,
  validateCatalog: (file) async {
    if (await file.readAsString() != 'valid catalog' &&
        await file.readAsString() != 'old catalog' &&
        await file.readAsString() != 'old valid catalog' &&
        await file.readAsString() != 'new catalog') {
      throw const CatalogValidationException();
    }
  },
);
