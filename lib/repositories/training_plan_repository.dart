import '../data/database_helper.dart';
import '../models/models.dart';

class TrainingPlanRepository {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<TrainingPlanInfo>> getPlans() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT tp.id, tp.training_id, tp.day_id,
             t.name AS training_name, d.name AS day_name
      FROM training_plans tp
      JOIN trainings t ON t.id = tp.training_id
      JOIN days d ON d.id = tp.day_id
      ORDER BY tp.day_id
    ''');
    return rows.map(TrainingPlanInfo.fromMap).toList();
  }

  Future<TrainingPlanInfo?> getPlan(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT tp.id, tp.training_id, tp.day_id,
             t.name AS training_name, d.name AS day_name
      FROM training_plans tp
      JOIN trainings t ON t.id = tp.training_id
      JOIN days d ON d.id = tp.day_id
      WHERE tp.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    return TrainingPlanInfo.fromMap(rows.first);
  }

  Future<TrainingPlanInfo?> getTodayPlan() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().weekday;
    final rows = await db.rawQuery('''
      SELECT tp.id, tp.training_id, tp.day_id,
             t.name AS training_name, d.name AS day_name
      FROM training_plans tp
      JOIN trainings t ON t.id = tp.training_id
      JOIN days d ON d.id = tp.day_id
      WHERE tp.day_id = ?
      LIMIT 1
    ''', [today]);
    if (rows.isEmpty) return null;
    return TrainingPlanInfo.fromMap(rows.first);
  }

  Future<List<PlanExercise>> getPlanExercises(int planId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT tpe.id, tpe.training_plan_id, tpe.exercise_id,
             e.name AS exercise_name, e.type AS exercise_type
      FROM training_plan_exercises tpe
      JOIN exercises e ON e.id = tpe.exercise_id
      WHERE tpe.training_plan_id = ?
      ORDER BY tpe.id
    ''', [planId]);
    return rows.map(PlanExercise.fromMap).toList();
  }

  Future<int> createPlan({
    required int trainingId,
    required int dayId,
    required List<int> exerciseIds,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final planId = await txn.insert('training_plans', {
        'training_id': trainingId,
        'day_id': dayId,
      });
      for (final exId in exerciseIds) {
        await txn.insert('training_plan_exercises', {
          'training_plan_id': planId,
          'exercise_id': exId,
        });
      }
      return planId;
    });
  }

  Future<void> updatePlan({
    required int planId,
    required int trainingId,
    required int dayId,
    required List<int> exerciseIds,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'training_plans',
        {'training_id': trainingId, 'day_id': dayId},
        where: 'id = ?',
        whereArgs: [planId],
      );

      final existing = await txn.query(
        'training_plan_exercises',
        where: 'training_plan_id = ?',
        whereArgs: [planId],
      );
      final existingByExercise = {
        for (final r in existing) r['exercise_id'] as int: r['id'] as int,
      };
      final desired = exerciseIds.toSet();

      for (final entry in existingByExercise.entries) {
        if (!desired.contains(entry.key)) {
          await txn.delete(
            'training_plan_exercises',
            where: 'id = ?',
            whereArgs: [entry.value],
          );
        }
      }
      for (final exId in desired) {
        if (!existingByExercise.containsKey(exId)) {
          await txn.insert('training_plan_exercises', {
            'training_plan_id': planId,
            'exercise_id': exId,
          });
        }
      }
    });
  }

  Future<void> deletePlan(int planId) async {
    final db = await _dbHelper.database;
    await db.delete('training_plans', where: 'id = ?', whereArgs: [planId]);
  }
}
