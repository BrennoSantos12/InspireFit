import '../data/database_helper.dart';
import '../models/models.dart';

class TrainingSessionRepository {
  final _dbHelper = DatabaseHelper.instance;

  static String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  Future<WeekSession> getThisWeekSession(int planId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final start = weekStart(now);
    final end = start.add(const Duration(days: 6));
    final rows = await db.query(
      'training_sessions',
      where: 'training_plan_id = ? AND performed_date BETWEEN ? AND ?',
      whereArgs: [planId, fmt(start), fmt(end)],
      orderBy: 'performed_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return const WeekSession(exists: false);
    return WeekSession(exists: true, sessionId: rows.first['id'] as int);
  }

  Future<int> createSession({
    required int planId,
    required DateTime performedDate,
    required List<ExecutionInput> executions,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final sessionId = await txn.insert('training_sessions', {
        'training_plan_id': planId,
        'performed_date': fmt(performedDate),
      });
      for (final e in executions) {
        await txn.insert('training_executions', {
          'training_session_id': sessionId,
          'training_plan_exercise_id': e.trainingPlanExerciseId,
          'sets_done': e.setsDone,
          'reps': e.reps,
          'weight': e.weight,
        });
      }
      return sessionId;
    });
  }

  Future<List<ExecutionInfo>> getSessionExecutions(int sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT te.id, te.training_plan_exercise_id, te.sets_done, te.reps, te.weight,
             e.name AS exercise_name
      FROM training_executions te
      JOIN training_plan_exercises tpe ON tpe.id = te.training_plan_exercise_id
      JOIN exercises e ON e.id = tpe.exercise_id
      WHERE te.training_session_id = ?
      ORDER BY te.id
    ''', [sessionId]);
    return rows.map(ExecutionInfo.fromMap).toList();
  }

  Future<int?> getSessionPlanId(int sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'training_sessions',
      columns: ['training_plan_id'],
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (rows.isEmpty) return null;
    return rows.first['training_plan_id'] as int;
  }

  Future<void> updateExecutions(List<ExecutionInfo> executions) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final e in executions) {
        await txn.update(
          'training_executions',
          {'sets_done': e.setsDone, 'reps': e.reps, 'weight': e.weight},
          where: 'id = ?',
          whereArgs: [e.id],
        );
      }
    });
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await _dbHelper.database;
    await db
        .delete('training_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<String?> getFirstDate(int planId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'training_sessions',
      columns: ['performed_date'],
      where: 'training_plan_id = ?',
      whereArgs: [planId],
      orderBy: 'performed_date ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['performed_date'] as String;
  }
}
