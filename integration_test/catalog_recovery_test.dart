import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_sky/core/database/catalog_installer.dart';
import 'package:offline_sky/core/database/catalog_repository.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'catalog installation recovers using the production SQLite validator',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'offline-sky-catalog-integration-',
      );
      try {
        Future<void> installBundled(File destination) async {
          final data = await rootBundle.load(
            'assets/catalogs/sky_catalog.sqlite',
          );
          await destination.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
        }

        CatalogInstaller installer({
          int revision = 1,
          CatalogFileWriter? write,
        }) => CatalogInstaller(
          catalogRevision: revision,
          writeBundledCatalog: write ?? installBundled,
          validateCatalog: CatalogRepository.validateCatalogFile,
        );

        final cleanPath = '${directory.path}/clean.sqlite';
        final cleanInstaller = installer();
        final firstOpen = Stopwatch()..start();
        await cleanInstaller.ensureInstalled(cleanPath);
        firstOpen.stop();
        expect(await File(cleanPath).exists(), isTrue);
        await CatalogRepository.validateCatalogFile(File(cleanPath));

        final database = await openDatabase(cleanPath, readOnly: true);
        final objects = await database.rawQuery(
          'SELECT COUNT(*) AS count FROM objects',
        );
        expect(objects.single['count'], greaterThan(0));
        await database.close();

        var unexpectedCopies = 0;
        final preserveInstaller = installer(
          write: (_) async {
            unexpectedCopies++;
          },
        );
        final repeatOpen = Stopwatch()..start();
        await preserveInstaller.ensureInstalled(cleanPath);
        repeatOpen.stop();
        expect(unexpectedCopies, 0);
        await CatalogRepository.validateCatalogFile(File(cleanPath));
        tester.printToConsole(
          'CATALOG_TIMING first_install_ms=${firstOpen.elapsedMilliseconds} '
          'existing_validation_ms=${repeatOpen.elapsedMilliseconds}',
        );

        final interruptedPath = '${directory.path}/interrupted.sqlite';
        var interruptFirstWrite = true;
        final interruptedInstaller = installer(
          write: (destination) async {
            if (interruptFirstWrite) {
              interruptFirstWrite = false;
              await destination.writeAsString('partial database', flush: true);
              throw const FileSystemException('simulated interrupted copy');
            }
            await installBundled(destination);
          },
        );
        await expectLater(
          interruptedInstaller.ensureInstalled(interruptedPath),
          throwsA(isA<FileSystemException>()),
        );
        expect(await File(interruptedPath).exists(), isFalse);
        expect(await File('$interruptedPath.installing').exists(), isFalse);
        await interruptedInstaller.ensureInstalled(interruptedPath);
        await CatalogRepository.validateCatalogFile(File(interruptedPath));

        final corruptPath = '${directory.path}/corrupt.sqlite';
        await File(corruptPath).writeAsString('not a SQLite database');
        await File('$corruptPath.revision').writeAsString('1\n');
        await installer().ensureInstalled(corruptPath);
        await CatalogRepository.validateCatalogFile(File(corruptPath));
        expect(await File('$corruptPath.installing').exists(), isFalse);

        final upgradePath = '${directory.path}/upgrade.sqlite';
        var upgradeCopies = 0;
        final revisionOne = installer(
          write: (file) async {
            upgradeCopies++;
            await installBundled(file);
          },
        );
        await revisionOne.ensureInstalled(upgradePath);
        await installer(
          revision: 2,
          write: (file) async {
            upgradeCopies++;
            await installBundled(file);
          },
        ).ensureInstalled(upgradePath);
        expect(upgradeCopies, 2);
        expect(await File('$upgradePath.revision').readAsString(), '2\n');
        await CatalogRepository.validateCatalogFile(File(upgradePath));

        final concurrentPath = '${directory.path}/concurrent.sqlite';
        var concurrentCopies = 0;
        final concurrentInstaller = installer(
          write: (file) async {
            concurrentCopies++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await installBundled(file);
          },
        );
        await Future.wait([
          concurrentInstaller.ensureInstalled(concurrentPath),
          concurrentInstaller.ensureInstalled(concurrentPath),
          concurrentInstaller.ensureInstalled(concurrentPath),
        ]);
        expect(concurrentCopies, 1);
        await CatalogRepository.validateCatalogFile(File(concurrentPath));

        for (final path in [
          cleanPath,
          interruptedPath,
          corruptPath,
          upgradePath,
          concurrentPath,
        ]) {
          expect(await File('$path.installing').exists(), isFalse);
          expect(await File('$path.revision.installing').exists(), isFalse);
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
