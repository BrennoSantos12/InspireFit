import '../data/database_helper.dart';
import '../models/report_models.dart';
import 'training_session_repository.dart';

class ReportRepository {
  final _dbHelper = DatabaseHelper.instance;

  DateTime _parse(String iso) {
    final parts = iso.split('-');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  DateTime _plannedDateInWeek(DateTime anyDayInWeek, int planDayId) {
    final start = TrainingSessionRepository.weekStart(anyDayInWeek);
    return start.add(Duration(days: planDayId - 1));
  }

  Future<List<PlanAdherence>> getPlanAdherence(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('start_date não pode ser maior que end_date');
    }
    final db = await _dbHelper.database;

    final plans = await db.rawQuery('''
      SELECT tp.id, tp.training_id, tp.day_id,
             t.name AS training_name, d.name AS day_name
      FROM training_plans tp
      JOIN trainings t ON t.id = tp.training_id
      JOIN days d ON d.id = tp.day_id
      ORDER BY tp.day_id
    ''');
    if (plans.isEmpty) return [];

    final start = TrainingSessionRepository.fmt(startDate);
    final end = TrainingSessionRepository.fmt(endDate);

    final report = <PlanAdherence>[];
    for (final p in plans) {
      final planId = p['id'] as int;
      final planDayId = p['day_id'] as int;

      int plannedTotal = 0;
      for (var d = DateTime(startDate.year, startDate.month, startDate.day);
          !d.isAfter(endDate);
          d = d.add(const Duration(days: 1))) {
        if (d.weekday == planDayId) plannedTotal++;
      }

      final sessions = await db.query(
        'training_sessions',
        columns: ['performed_date'],
        where:
            'training_plan_id = ? AND performed_date BETWEEN ? AND ?',
        whereArgs: [planId, start, end],
      );

      int doneRight = 0, doneEarly = 0, doneWrong = 0;
      final seen = <String>{};
      for (final s in sessions) {
        final iso = s['performed_date'] as String;
        if (seen.contains(iso)) continue;
        seen.add(iso);
        final d = _parse(iso);
        if (d.weekday == planDayId) {
          doneRight++;
        } else {
          final planned = _plannedDateInWeek(d, planDayId);
          if (d.isBefore(planned)) {
            doneEarly++;
          } else {
            doneWrong++;
          }
        }
      }

      final doneTotal = doneRight + doneEarly + doneWrong;
      final notDone =
          (plannedTotal - doneTotal) > 0 ? plannedTotal - doneTotal : 0;

      report.add(PlanAdherence(
        trainingPlanId: planId,
        trainingId: p['training_id'] as int,
        dayId: planDayId,
        trainingName: p['training_name'] as String,
        dayName: p['day_name'] as String,
        plannedTotal: plannedTotal,
        doneRightDay: doneRight,
        doneEarly: doneEarly,
        doneWrongDay: doneWrong,
        notDone: notDone,
      ));
    }
    return report;
  }

  Future<List<ExerciseProgress>> getExerciseProgress(
    int planId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('start_date não pode ser maior que end_date');
    }
    final db = await _dbHelper.database;

    final planExercises = await db.rawQuery('''
      SELECT tpe.id AS plan_ex_id, e.id AS exercise_id,
             e.name AS exercise_name, e.type AS exercise_type
      FROM training_plan_exercises tpe
      JOIN exercises e ON e.id = tpe.exercise_id
      WHERE tpe.training_plan_id = ?
      ORDER BY tpe.id
    ''', [planId]);
    if (planExercises.isEmpty) return [];

    final start = TrainingSessionRepository.fmt(startDate);
    final end = TrainingSessionRepository.fmt(endDate);

    final sessions = await db.query(
      'training_sessions',
      columns: ['id'],
      where: 'training_plan_id = ? AND performed_date BETWEEN ? AND ?',
      whereArgs: [planId, start, end],
    );
    final totalSessions = sessions.length;
    final sessionIds = sessions.map((s) => s['id'] as int).toList();

    final List<Map<String, Object?>> executions;
    if (sessionIds.isEmpty) {
      executions = [];
    } else {
      final placeholders = List.filled(sessionIds.length, '?').join(',');
      executions = await db.rawQuery('''
        SELECT te.training_plan_exercise_id, te.sets_done, te.reps, te.weight,
               ts.performed_date
        FROM training_executions te
        JOIN training_sessions ts ON ts.id = te.training_session_id
        WHERE te.training_session_id IN ($placeholders)
        ORDER BY ts.performed_date
      ''', sessionIds);
    }

    final byPlanEx = <int, List<Map<String, Object?>>>{};
    for (final e in executions) {
      final id = e['training_plan_exercise_id'] as int;
      byPlanEx.putIfAbsent(id, () => []).add(e);
    }

    final report = <ExerciseProgress>[];
    for (final pe in planExercises) {
      final planExId = pe['plan_ex_id'] as int;
      final list = byPlanEx[planExId] ?? [];
      final timesPerformed = list.length;
      final timesSkipped = (totalSessions - timesPerformed) > 0
          ? totalSessions - timesPerformed
          : 0;

      ExecutionStats? first, best, last;
      String? improvementSummary;
      double? improvementPct;

      if (list.isNotEmpty) {
        final sorted = [...list]..sort((a, b) => (a['performed_date'] as String)
            .compareTo(b['performed_date'] as String));

        first = _stats(sorted.first);
        last = _stats(sorted.last);
        best = _findBest(sorted);

        if (sorted.length > 1) {
          final mid = sorted.length ~/ 2;
          final avgFirst = _avg(sorted.sublist(0, mid));
          final avgLast = _avg(sorted.sublist(mid));
          if (avgFirst != null && avgLast != null) {
            improvementSummary = _summary(avgFirst, avgLast);
            improvementPct = _percentage(avgFirst, avgLast);
          }
        }
      }

      report.add(ExerciseProgress(
        exerciseId: pe['exercise_id'] as int,
        exerciseName: pe['exercise_name'] as String,
        exerciseType: pe['exercise_type'] as String,
        timesPerformed: timesPerformed,
        timesSkipped: timesSkipped,
        firstExecution: first,
        bestExecution: best,
        lastExecution: last,
        improvementSummary: improvementSummary,
        improvementPercentage: improvementPct,
      ));
    }
    return report;
  }

  ExecutionStats _stats(Map<String, Object?> m) => ExecutionStats(
        setsDone: m['sets_done'] as int?,
        reps: (m['reps'] as num?)?.toDouble(),
        weight: (m['weight'] as num?)?.toDouble(),
        performedDate: m['performed_date'] as String,
      );

  double? _volume(ExecutionStats s) {
    if (s.setsDone != null && s.reps != null && s.weight != null) {
      return s.setsDone! * s.reps! * s.weight!;
    }
    if (s.setsDone != null && s.reps != null) {
      return s.setsDone! * s.reps!;
    }
    return null;
  }

  ExecutionStats? _findBest(List<Map<String, Object?>> execs) {
    ExecutionStats? best;
    double bestVolume = 0;
    for (final m in execs) {
      final s = _stats(m);
      final v = _volume(s) ?? 0;
      if (v > bestVolume) {
        bestVolume = v;
        best = s;
      }
    }
    return best;
  }

  ExecutionStats? _avg(List<Map<String, Object?>> execs) {
    if (execs.isEmpty) return null;
    final sets = execs
        .map((e) => e['sets_done'] as int?)
        .whereType<int>()
        .toList();
    final reps =
        execs.map((e) => (e['reps'] as num?)?.toDouble()).whereType<double>().toList();
    final weights = execs
        .map((e) => (e['weight'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    double? mean(List<num> xs) =>
        xs.isEmpty ? null : xs.fold<double>(0, (a, b) => a + b) / xs.length;

    final avgSets = mean(sets);
    final avgReps = mean(reps);
    final avgWeight = mean(weights);

    return ExecutionStats(
      setsDone: avgSets?.round(),
      reps: avgReps,
      weight: avgWeight,
      performedDate: execs.last['performed_date'] as String,
    );
  }

  String _summary(ExecutionStats first, ExecutionStats last) {
    final parts = <String>[];
    if (first.setsDone != null &&
        last.setsDone != null &&
        first.setsDone != last.setsDone) {
      final diff = last.setsDone! - first.setsDone!;
      parts.add('${diff > 0 ? '+' : ''}$diff séries');
    }
    if (first.reps != null && last.reps != null && first.reps != last.reps) {
      final diff = last.reps! - first.reps!;
      parts.add('${diff > 0 ? '+' : ''}${_n(diff)} reps');
    }
    if (first.weight != null &&
        last.weight != null &&
        first.weight != last.weight) {
      final diff = last.weight! - first.weight!;
      parts.add('${diff > 0 ? '+' : ''}${_n(diff)}kg');
    }
    if (parts.isEmpty) return 'Sem mudanças significativas';
    return 'Evolução: ${parts.join(', ')}';
  }

  double? _percentage(ExecutionStats first, ExecutionStats last) {
    final fv = _volume(first);
    final lv = _volume(last);
    if (fv == null || fv == 0 || lv == null) return null;
    return double.parse((((lv - fv) / fv) * 100).toStringAsFixed(2));
  }

  String _n(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1);
}
