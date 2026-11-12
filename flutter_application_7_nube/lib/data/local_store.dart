import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

class PendingOperation {
  final int sequence;
  final Task task;
  PendingOperation(this.sequence, this.task);
}

class LocalStore {
  final Database db;
  LocalStore(this.db);
  static Future<LocalStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final location = path ?? p.join(await f.getDatabasesPath(), 'synclab.db');
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE tasks (
          id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL, user_id TEXT,
          completed INTEGER NOT NULL, deleted INTEGER NOT NULL,
          pending INTEGER NOT NULL, revision INTEGER NOT NULL)''');
          await db.execute('''CREATE TABLE outbox (
          sequence INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id TEXT NOT NULL REFERENCES tasks(id), revision INTEGER NOT NULL,
          payload TEXT NOT NULL)''');
          await db.execute('CREATE INDEX outbox_task ON outbox(task_id)');
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    return LocalStore(db);
  }

  Future<List<Task>> tasks({bool includeDeleted = false}) async =>
      (await db.query(
        'tasks',
        where: includeDeleted ? null : 'deleted = 0',
        orderBy: 'created_at DESC',
      )).map(Task.fromMap).toList();
  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM outbox')) ??
      0;
  Future<String?> metadata(String key) async {
    final rows = await db.query('metadata', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMetadata(String key, String value) => db.insert('metadata', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // La edición y su instantánea de envío se confirman en una sola transacción.
  Future<void> save(Task task) => db.transaction((tx) async {
    final old = await tx.query('tasks', where: 'id = ?', whereArgs: [task.id]);
    final map = task.toLocal();
    map['revision'] = old.isEmpty ? 1 : (old.first['revision'] as int) + 1;
    map['pending'] = 1;
    if (old.isEmpty) {
      await tx.insert('tasks', map);
    } else {
      map['user_id'] = old.first['user_id'];
      map['created_at'] = old.first['created_at'];
      await tx.update('tasks', map, where: 'id = ?', whereArgs: [task.id]);
    }
    await tx.insert('outbox', {
      'task_id': task.id,
      'revision': map['revision'],
      'payload': jsonEncode(map),
    });
  });
  Future<void> bindOwner(String owner) => db.transaction((tx) async {
    final prior = await tx.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['owner'],
    );
    if (prior.isNotEmpty && prior.first['value'] != owner) {
      throw StateError(
        'La sesión cambió de propietario. Se conservan los datos locales; recupera la sesión original.',
      );
    }
    await tx.insert('metadata', {
      'key': 'owner',
      'value': owner,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await tx.update('tasks', {'user_id': owner}, where: 'user_id IS NULL');
  });
  Future<PendingOperation?> next() async {
    final rows = await db.query('outbox', orderBy: 'sequence', limit: 1);
    if (rows.isEmpty) return null;
    return PendingOperation(
      rows.first['sequence'] as int,
      Task.fromMap(
        Map<String, dynamic>.from(
          jsonDecode(rows.first['payload'] as String) as Map,
        ),
      ),
    );
  }

  Future<void> acknowledge(PendingOperation op, String owner) =>
      db.transaction((tx) async {
        await tx.delete(
          'outbox',
          where: 'sequence = ?',
          whereArgs: [op.sequence],
        );
        // Una respuesta antigua nunca confirma una edición local más reciente.
        await tx.update(
          'tasks',
          {'pending': 0, 'user_id': owner},
          where: 'id = ? AND revision = ?',
          whereArgs: [op.task.id, op.task.revision],
        );
      });
  Future<void> merge(List<Task> remote) => db.transaction((tx) async {
    for (final task in remote) {
      final pending = await tx.query(
        'outbox',
        where: 'task_id = ?',
        whereArgs: [task.id],
        limit: 1,
      );
      if (pending.isNotEmpty) continue;
      final map = task.toLocal()..['pending'] = 0;
      await tx.insert(
        'tasks',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  });
}
