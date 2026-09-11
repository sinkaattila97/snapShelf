import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/shot.dart';
import 'sqlite_desktop.dart' as desktop;

abstract class ShotRepository {
  Future<void> init();
  Future<List<Shot>> getAll();
  Future<List<Shot>> search(String query);
  Future<List<Shot>> byShelf(String shelf);
  Future<void> upsert(Shot shot);
  Future<void> delete(String id);
  Future<Set<String>> linkedPhotoAssetIds();
  Future<void> close();
}

int compareShotsForInbox(Shot a, Shot b) {
  final au = a.needsLabel ? 0 : 1;
  final bu = b.needsLabel ? 0 : 1;
  if (au != bu) return au.compareTo(bu);
  return b.createdAt.compareTo(a.createdAt);
}


/// In-memory store for widget tests.
class MemoryShotRepository implements ShotRepository {
  final List<Shot> _shots = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<Shot>> getAll() async {
    final copy = List<Shot>.from(_shots);
    copy.sort(compareShotsForInbox);
    return copy;
  }

  @override
  Future<List<Shot>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAll();
    final all = await getAll();
    return all.where((s) {
      return s.label.toLowerCase().contains(q) ||
          s.displayLabel.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Shot>> byShelf(String shelf) async {
    final all = await getAll();
    return all.where((s) => s.shelves.contains(shelf)).toList();
  }

  @override
  Future<void> upsert(Shot shot) async {
    _shots.removeWhere((s) => s.id == shot.id);
    _shots.add(shot);
  }

  @override
  Future<void> delete(String id) async {
    _shots.removeWhere((s) => s.id == id);
  }

  @override
  Future<Set<String>> linkedPhotoAssetIds() async {
    return _shots
        .map((s) => s.photoAssetId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> close() async {}
}

/// JSON in SharedPreferences — works on web (Chrome UI loop).
class PrefsShotRepository implements ShotRepository {
  static const _key = 'snapshelf_shots_v1';
  SharedPreferences? _prefs;
  List<Shot> _cache = [];

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return;
    }
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .map((e) => Shot.fromJson(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_cache.map((s) => s.toJson()).toList());
    await _prefs!.setString(_key, encoded);
  }

  @override
  Future<List<Shot>> getAll() async {
    final copy = List<Shot>.from(_cache);
    copy.sort(compareShotsForInbox);
    return copy;
  }

  @override
  Future<List<Shot>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAll();
    final all = await getAll();
    return all.where((s) {
      return s.label.toLowerCase().contains(q) ||
          s.displayLabel.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Shot>> byShelf(String shelf) async {
    final all = await getAll();
    return all.where((s) => s.shelves.contains(shelf)).toList();
  }

  @override
  Future<void> upsert(Shot shot) async {
    _cache.removeWhere((s) => s.id == shot.id);
    _cache.add(shot);
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    _cache.removeWhere((s) => s.id == id);
    await _persist();
  }

  @override
  Future<Set<String>> linkedPhotoAssetIds() async {
    return _cache
        .map((s) => s.photoAssetId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> close() async {}
}

/// sqflite on Android / iOS / desktop (FFI on Windows / Linux / macOS).
class SqliteShotRepository implements ShotRepository {
  Database? _db;

  @override
  Future<void> init() async {
    await desktop.ensureDesktopFactory();
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'snapshelf.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shots (
            id TEXT PRIMARY KEY,
            label TEXT NOT NULL,
            shelves TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            localPath TEXT,
            photoAssetId TEXT
          )
        ''');
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('ShotRepository not initialized');
    }
    return db;
  }

  @override
  Future<List<Shot>> getAll() async {
    final rows = await _database.query('shots', orderBy: 'createdAt DESC');
    final shots = rows.map(Shot.fromMap).toList()..sort(compareShotsForInbox);
    return shots;
  }

  @override
  Future<List<Shot>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return getAll();
    final all = await getAll();
    final needle = q.toLowerCase();
    return all.where((s) {
      return s.label.toLowerCase().contains(needle) ||
          s.displayLabel.toLowerCase().contains(needle);
    }).toList();
  }

  @override
  Future<List<Shot>> byShelf(String shelf) async {
    final rows = await _database.query(
      'shots',
      where: 'shelves = ? OR shelves LIKE ? OR shelves LIKE ? OR shelves LIKE ?',
      whereArgs: [shelf, '$shelf,%', '%,$shelf', '%,$shelf,%'],
      orderBy: 'createdAt DESC',
    );
    final shots = rows.map(Shot.fromMap).toList()..sort(compareShotsForInbox);
    return shots;
  }

  @override
  Future<void> upsert(Shot shot) async {
    await _database.insert(
      'shots',
      shot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _database.delete('shots', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Set<String>> linkedPhotoAssetIds() async {
    final rows = await _database.query(
      'shots',
      columns: ['photoAssetId'],
      where: 'photoAssetId IS NOT NULL AND photoAssetId != ?',
      whereArgs: [''],
    );
    return rows
        .map((r) => r['photoAssetId'] as String?)
        .whereType<String>()
        .toSet();
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

Future<ShotRepository> createDefaultShotRepository() async {
  final ShotRepository repo =
      kIsWeb ? PrefsShotRepository() : SqliteShotRepository();
  await repo.init();
  return repo;
}
