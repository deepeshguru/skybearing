import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'catalog_installer.dart';
import '../models/celestial_object.dart';

abstract interface class CatalogStore {
  Future<List<CelestialObject>> search(String query, {int limit = 60});
  Future<CelestialObject?> getById(String id);
  Future<List<CelestialObject>> loadStars();
  Future<List<CelestialObject>> loadDeepSkyObjects();
  Future<List<CelestialObject>> loadNotableObjects();
  Future<List<Constellation>> loadConstellations();
  Future<List<ConstellationSegment>> loadConstellationSegments();
  Future<void> close();
}

class CatalogRepository implements CatalogStore {
  CatalogRepository._(this._database);

  final Database _database;
  List<CelestialObject>? _stars;
  List<CelestialObject>? _deepSkyObjects;
  List<CelestialObject>? _notableObjects;
  List<Constellation>? _constellations;
  List<ConstellationSegment>? _segments;

  static Future<CatalogRepository> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documents.path, 'sky_catalog.sqlite');
    final installer = CatalogInstaller(
      writeBundledCatalog: (destination) async {
        final bytes = await rootBundle.load(
          'assets/catalogs/sky_catalog.sqlite',
        );
        await destination.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      },
      validateCatalog: validateCatalogFile,
    );
    await installer.ensureInstalled(databasePath);
    final database = await openDatabase(databasePath, readOnly: true);
    return CatalogRepository._(database);
  }

  static Future<void> validateCatalogFile(File file) async {
    if (!await file.exists() || await file.length() == 0) {
      throw const CatalogValidationException('Catalog file is empty.');
    }

    Database? database;
    try {
      database = await openDatabase(
        file.path,
        readOnly: true,
        singleInstance: false,
      );
      final check = await database.rawQuery('PRAGMA integrity_check');
      if (check.length != 1 || check.single.values.single != 'ok') {
        throw const CatalogValidationException(
          'Catalog failed SQLite integrity_check.',
        );
      }

      const requiredColumns = <String, Set<String>>{
        'objects': {
          'id',
          'name',
          'kind',
          'ra_hours',
          'dec_deg',
          'epoch',
          'pmra_masyr',
          'pmdec_masyr',
          'magnitude',
          'magnitude_band',
          'distance_ly',
          'constellation',
          'description',
          'aliases',
          'search_text',
        },
        'constellations': {'abbreviation', 'name', 'aliases'},
        'constellation_lines': {'constellation', 'hip_from', 'hip_to'},
      };
      for (final entry in requiredColumns.entries) {
        final columns = await database.rawQuery(
          'PRAGMA table_info(${entry.key})',
        );
        final names = columns.map((row) => row['name']).whereType<String>();
        if (!names.toSet().containsAll(entry.value)) {
          throw CatalogValidationException(
            'Catalog table ${entry.key} has an incompatible schema.',
          );
        }
      }
      final rowCounts = await database.rawQuery('''
        SELECT
          (SELECT COUNT(*) FROM objects) AS objects,
          (SELECT COUNT(*) FROM constellations) AS constellations,
          (SELECT COUNT(*) FROM constellation_lines) AS segments
      ''');
      final counts = rowCounts.single;
      if ((counts['objects'] as int? ?? 0) == 0 ||
          (counts['constellations'] as int? ?? 0) == 0 ||
          (counts['segments'] as int? ?? 0) == 0) {
        throw const CatalogValidationException(
          'Catalog is missing required astronomy records.',
        );
      }
    } on DatabaseException catch (error) {
      final resultCode = error.getResultCode();
      final primaryCode = resultCode == null ? null : resultCode & 0xff;
      final message = error.toString().toLowerCase();
      if (primaryCode == 11 ||
          primaryCode == 26 ||
          message.contains('malformed') ||
          message.contains('not a database')) {
        throw const CatalogValidationException('Catalog database is corrupt.');
      }
      rethrow;
    } finally {
      await database?.close();
    }
  }

  @override
  Future<List<CelestialObject>> search(String query, {int limit = 60}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final escaped = normalized
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await _database.rawQuery(
      '''
      SELECT * FROM objects
      WHERE search_text LIKE ? ESCAPE '\\' OR lower(id) LIKE ? ESCAPE '\\'
      ORDER BY
        CASE
          WHEN lower(name) = ? OR lower(id) = ? THEN 0
          WHEN lower(name) LIKE ? ESCAPE '\\' THEN 1
          ELSE 2
        END,
        CASE WHEN magnitude IS NULL THEN 1 ELSE 0 END,
        magnitude ASC
      LIMIT ?
      ''',
      ['%$escaped%', '%$escaped%', normalized, normalized, '$escaped%', limit],
    );
    final notableObjects = (await loadNotableObjects()).where((object) {
      return object.name.toLowerCase().contains(normalized) ||
          object.id.toLowerCase().contains(normalized) ||
          object.aliases.any(
            (alias) => alias.toLowerCase().contains(normalized),
          );
    });
    return [
      ...rows.map(_objectFromRow),
      ...notableObjects,
    ].take(limit).toList(growable: false);
  }

  @override
  Future<CelestialObject?> getById(String id) async {
    for (final object in await loadNotableObjects()) {
      if (object.id == id) return object;
    }
    final rows = await _database.query(
      'objects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _objectFromRow(rows.first);
  }

  @override
  Future<List<CelestialObject>> loadStars() async {
    return _stars ??= (await _database.query(
      'objects',
      where: "kind = 'Star'",
      orderBy: 'magnitude ASC',
    )).map(_objectFromRow).toList(growable: false);
  }

  @override
  Future<List<CelestialObject>> loadDeepSkyObjects() async {
    if (_deepSkyObjects != null) return _deepSkyObjects!;
    final catalogObjects = (await _database.query(
      'objects',
      where: "kind != 'Star'",
      orderBy: 'magnitude ASC',
    )).map(_objectFromRow).toList(growable: false);
    return _deepSkyObjects = [...catalogObjects, ...await loadNotableObjects()];
  }

  @override
  Future<List<CelestialObject>> loadNotableObjects() async {
    if (_notableObjects != null) return _notableObjects!;
    final source = await rootBundle.loadString(
      'assets/catalogs/notable_objects.json',
    );
    final entries = jsonDecode(source) as List<Object?>;
    return _notableObjects = entries
        .map((value) {
          final row = value! as Map<String, Object?>;
          return CelestialObject(
            id: row['id']! as String,
            name: row['name']! as String,
            type: celestialTypeFromName(row['kind'] as String? ?? 'black hole'),
            rightAscensionHoursJ2000: (row['ra_hours']! as num).toDouble(),
            declinationDegreesJ2000: (row['dec_deg']! as num).toDouble(),
            epoch: 2000,
            description: row['description']! as String,
            aliases: (row['aliases']! as List<Object?>).cast<String>(),
            source: row['source']! as String,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<Constellation>> loadConstellations() async {
    return _constellations ??=
        (await _database.query('constellations', orderBy: 'name ASC'))
            .map((row) {
              return Constellation(
                abbreviation: row['abbreviation']! as String,
                name: row['name']! as String,
                aliases: _splitAliases(row['aliases'] as String?),
              );
            })
            .toList(growable: false);
  }

  @override
  Future<List<ConstellationSegment>> loadConstellationSegments() async {
    return _segments ??= (await _database.query('constellation_lines'))
        .map((row) {
          return ConstellationSegment(
            abbreviation: row['constellation']! as String,
            fromHip: row['hip_from']! as int,
            toHip: row['hip_to']! as int,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> close() => _database.close();

  CelestialObject _objectFromRow(Map<String, Object?> row) {
    return CelestialObject(
      id: row['id']! as String,
      name: row['name']! as String,
      type: celestialTypeFromName(row['kind']! as String),
      rightAscensionHoursJ2000: (row['ra_hours']! as num).toDouble(),
      declinationDegreesJ2000: (row['dec_deg']! as num).toDouble(),
      epoch: (row['epoch']! as num).toDouble(),
      properMotionRaMasPerYear: (row['pmra_masyr'] as num?)?.toDouble(),
      properMotionDecMasPerYear: (row['pmdec_masyr'] as num?)?.toDouble(),
      magnitude: (row['magnitude'] as num?)?.toDouble(),
      magnitudeBand: row['magnitude_band'] as String?,
      distanceLightYears: (row['distance_ly'] as num?)?.toDouble(),
      constellation: row['constellation'] as String?,
      description: row['description']! as String,
      aliases: _splitAliases(row['aliases'] as String?),
      source: row['source']! as String,
    );
  }

  List<String> _splitAliases(String? value) =>
      value == null || value.isEmpty ? const [] : value.split('|');
}
