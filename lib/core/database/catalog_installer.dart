import 'dart:io';

import 'package:path/path.dart' as path;

typedef CatalogFileWriter = Future<void> Function(File destination);
typedef CatalogFileValidator = Future<void> Function(File file);

/// Coordinates safe installation of the bundled, read-only sky catalog.
///
/// Bump [catalogRevision] whenever the bundled catalog's data or schema
/// changes. An unmarked database is treated as revision 1 to preserve valid
/// installations created by older app versions.
class CatalogInstaller {
  CatalogInstaller({
    required this.writeBundledCatalog,
    required this.validateCatalog,
    this.catalogRevision = 1,
  });

  final CatalogFileWriter writeBundledCatalog;
  final CatalogFileValidator validateCatalog;
  final int catalogRevision;

  static final Map<String, Future<void>> _installations = {};

  Future<void> ensureInstalled(String databasePath) async {
    final absolutePath = path.absolute(databasePath);
    final active = _installations[absolutePath];
    if (active != null) {
      await active;
      return;
    }

    final installation = _installUnderLock(absolutePath);
    _installations[absolutePath] = installation;
    try {
      await installation;
    } finally {
      if (identical(_installations[absolutePath], installation)) {
        _installations.remove(absolutePath);
      }
    }
  }

  Future<void> _installUnderLock(String databasePath) async {
    if (catalogRevision < 1) {
      throw ArgumentError.value(catalogRevision, 'catalogRevision');
    }

    final directory = Directory(path.dirname(databasePath));
    await directory.create(recursive: true);

    final lockFile = File('$databasePath.install.lock');
    final lockHandle = await lockFile.open(mode: FileMode.append);

    final databaseFile = File(databasePath);
    final revisionFile = File('$databasePath.revision');
    final temporaryDatabase = File('$databasePath.installing');
    final temporaryRevision = File('$databasePath.revision.installing');
    var locked = false;
    try {
      await lockHandle.lock(FileLock.exclusive);
      locked = true;
      final databaseExists = await databaseFile.exists();
      if (databaseExists && await _isValid(databaseFile)) {
        final revision = await _readRevision(revisionFile);
        // Older app versions installed this file without a revision marker.
        // Keep it if it is valid, then mark it as the current initial revision.
        if (revision == null || revision == catalogRevision) {
          if (revision == null) {
            await _writeRevisionAtomically(temporaryRevision, revisionFile);
          }
          return;
        }
      }

      await _deleteIfPresent(temporaryDatabase);
      await _deleteIfPresent(temporaryRevision);
      await writeBundledCatalog(temporaryDatabase);
      await validateCatalog(temporaryDatabase);
      await temporaryDatabase.rename(databasePath);
      await _writeRevisionAtomically(temporaryRevision, revisionFile);
    } finally {
      try {
        await _deleteIfPresent(temporaryDatabase);
        await _deleteIfPresent(temporaryRevision);
      } finally {
        try {
          if (locked) await lockHandle.unlock();
        } finally {
          await lockHandle.close();
        }
      }
    }
  }

  Future<bool> _isValid(File file) async {
    try {
      await validateCatalog(file);
      return true;
    } on CatalogValidationException {
      return false;
    }
  }

  Future<int?> _readRevision(File file) async {
    if (!await file.exists()) return null;
    return int.tryParse((await file.readAsString()).trim()) ?? -1;
  }

  Future<void> _writeRevisionAtomically(
    File temporaryRevision,
    File revisionFile,
  ) async {
    await temporaryRevision.writeAsString('$catalogRevision\n', flush: true);
    await temporaryRevision.rename(revisionFile.path);
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}

/// Signals that the file is not a usable version of the sky catalog.
class CatalogValidationException implements Exception {
  const CatalogValidationException([this.message = 'Invalid sky catalog']);

  final String message;

  @override
  String toString() => message;
}
