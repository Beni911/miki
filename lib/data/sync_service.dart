import 'package:sqflite/sqflite.dart';
import 'database.dart';

abstract class RemoteGateway {
  bool get isConfigured;
  String? get userId;
  String? get userEmail;

  Future<void> signIn(String email, String password);
  Future<bool> signUp(String email, String password);
  Future<void> signOut();
  Future<void> upsert(String table, List<Map<String, Object?>> rows);
  Future<void> remove(String table, List<String> ids);
  Future<void> removeRelated(String table, String column, String value);
  Future<List<Map<String, Object?>>> fetchAll(String table);
}

class NoRemote implements RemoteGateway {
  @override
  bool get isConfigured => false;
  @override
  String? get userId => null;
  @override
  String? get userEmail => null;
  @override
  Future<void> signIn(String email, String password) => _notConfigured();
  @override
  Future<bool> signUp(String email, String password) => _notConfigured();
  @override
  Future<void> signOut() => _notConfigured();
  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) => _notConfigured();
  @override
  Future<void> remove(String table, List<String> ids) => _notConfigured();
  @override
  Future<void> removeRelated(String table, String column, String value) => _notConfigured();
  @override
  Future<List<Map<String, Object?>>> fetchAll(String table) => _notConfigured();

  Future<T> _notConfigured<T>() => Future.error(StateError('Cloud sync is not configured.'));
}

class SyncStatus {
  final int pending;
  final bool configured;
  final String? userEmail;

  const SyncStatus(this.pending, this.configured, this.userEmail);

  bool get signedIn => userEmail != null;
}

/// Keeps SQLite authoritative for editing and uses the outbox for reliable
/// uploads. Each sync then merges the account's cloud snapshot into SQLite.
class SyncService {
  final AppDatabase _app;
  final RemoteGateway remote;
  SyncService(this._app, this.remote);

  Future<SyncStatus> status() async {
    final db = await _app.db;
    final n = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_outbox')) ?? 0;
    return SyncStatus(n, remote.isConfigured, remote.userEmail);
  }

  Future<int> syncNow() async {
    if (!remote.isConfigured) {
      throw StateError('Cloud sync is not configured.');
    }
    final userId = remote.userId;
    if (userId == null) {
      throw StateError('Sign in before syncing.');
    }

    final db = await _app.db;
    final account = await db.query('sync_metadata', where: 'key = ?', whereArgs: ['account_id'], limit: 1);
    if (account.isNotEmpty && account.first['value'] != userId) {
      throw StateError(
        "This device is linked to another cloud account. Use the same account or clear this device's app data first.",
      );
    }
    if (account.isEmpty) {
      await db.insert('sync_metadata', {'key': 'account_id', 'value': userId});
    }

    final cloud = <String, List<Map<String, Object?>>>{};
    for (final table in kTables) {
      cloud[table] = await remote.fetchAll(table);
    }

    var done = 0;
    if (cloud.values.every((rows) => rows.isEmpty)) {
      for (final table in kTables) {
        final localRows = await db.query(table);
        if (localRows.isNotEmpty) {
          await remote.upsert(table, localRows);
          done += localRows.length;
        }
      }
    }

    final items = await db.query('sync_outbox', orderBy: 'id ASC');
    for (final item in items) {
      final entity = item['entity'] as String;
      final id = item['entity_id'] as String;
      if (item['op'] == 'delete') {
        await remote.remove(_tableFor(entity), [id]);
      } else {
        await _push(db, entity, id);
      }
      await db.delete('sync_outbox', where: 'id = ?', whereArgs: [item['id']]);
      done++;
    }

    for (final table in kTables) {
      cloud[table] = await remote.fetchAll(table);
    }
    await _mergeSnapshot(db, cloud);
    return done;
  }

  String _tableFor(String entity) => switch (entity) {
        'workout' => 'workouts',
        'exercise' => 'exercises',
        'program' => 'programs',
        'record' => 'personal_records',
        'bodyweight' => 'bodyweight',
        _ => throw StateError('Unsupported sync entity: $entity'),
      };

  Future<void> _push(Database db, String entity, String id) async {
    switch (entity) {
      case 'workout':
        await remote.upsert('workouts', await db.query('workouts', where: 'id = ?', whereArgs: [id]));
        await remote.removeRelated('workout_exercises', 'workout_id', id);
        final exercises = await db.query('workout_exercises', where: 'workout_id = ?', whereArgs: [id]);
        await remote.upsert('workout_exercises', exercises);
        for (final exercise in exercises) {
          await remote.upsert(
            'workout_sets',
            await db.query('workout_sets', where: 'workout_exercise_id = ?', whereArgs: [exercise['id']]),
          );
        }
      case 'exercise':
        await remote.upsert('exercises', await db.query('exercises', where: 'id = ?', whereArgs: [id]));
      case 'record':
        await remote.upsert('personal_records', await db.query('personal_records', where: 'id = ?', whereArgs: [id]));
      case 'bodyweight':
        await remote.upsert('bodyweight', await db.query('bodyweight', where: 'id = ?', whereArgs: [id]));
      case 'program':
        await remote.upsert('programs', await db.query('programs', where: 'id = ?', whereArgs: [id]));
        await remote.removeRelated('program_blocks', 'program_id', id);
        final blocks = await db.query('program_blocks', where: 'program_id = ?', whereArgs: [id]);
        await remote.upsert('program_blocks', blocks);
        for (final block in blocks) {
          final days = await db.query('program_days', where: 'block_id = ?', whereArgs: [block['id']]);
          await remote.upsert('program_days', days);
          for (final day in days) {
            final exercises = await db.query('program_exercises', where: 'day_id = ?', whereArgs: [day['id']]);
            await remote.upsert('program_exercises', exercises);
            for (final exercise in exercises) {
              await remote.upsert(
                'program_sets',
                await db.query('program_sets', where: 'program_exercise_id = ?', whereArgs: [exercise['id']]),
              );
            }
          }
        }
      default:
        throw StateError('Unsupported sync entity: $entity');
    }
  }

  Future<void> _mergeSnapshot(Database db, Map<String, List<Map<String, Object?>>> cloud) async {
    await db.transaction((txn) async {
      for (final table in kTables.reversed) {
        final remoteRows = cloud[table]!;
        final remoteIds = remoteRows.map((row) => row['id']).toSet();
        final localRows = await txn.query(table);
        for (final local in localRows) {
          final id = local['id'];
          final isBuiltInExercise = table == 'exercises' && (local['is_custom'] as int? ?? 0) == 0;
          if (!remoteIds.contains(id) && !isBuiltInExercise) {
            await txn.delete(table, where: 'id = ?', whereArgs: [id]);
          }
        }
      }

      for (final table in kTables) {
        for (final remoteRow in cloud[table]!) {
          final localRow = Map<String, Object?>.from(remoteRow)..remove('user_id');
          await txn.insert(table, localRow, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
