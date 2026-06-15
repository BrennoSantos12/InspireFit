import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'seeds/days_seed.dart';
import 'seeds/trainings_seed.dart';
import 'seeds/exercises_seed.dart';

/// Singleton de acesso ao banco SQLite local do dispositivo.
///
/// Cria o schema (espelhando o canvas, sem `user_id`) e popula os seeds de
/// dias, treinos e exercícios na primeira execução. Mantém
/// `PRAGMA foreign_keys = ON` para garantir os ON DELETE CASCADE.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'inspirefit.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE trainings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE training_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        training_id INTEGER NOT NULL REFERENCES trainings(id),
        day_id INTEGER NOT NULL REFERENCES days(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE training_plan_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        training_plan_id INTEGER NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL REFERENCES exercises(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE training_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        training_plan_id INTEGER NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
        performed_date TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE training_executions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        training_session_id INTEGER NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
        training_plan_exercise_id INTEGER NOT NULL REFERENCES training_plan_exercises(id) ON DELETE CASCADE,
        sets_done INTEGER,
        reps REAL,
        weight REAL
      )
    ''');

    await batch.commit(noResult: true);

    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    final batch = db.batch();

    for (final name in kDaysSeed) {
      batch.insert('days', {'name': name});
    }
    for (final name in kTrainingsSeed) {
      batch.insert('trainings', {'name': name});
    }
    for (final ex in kExercisesSeed) {
      batch.insert(
        'exercises',
        {'name': ex.name, 'type': ex.type},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }
}
