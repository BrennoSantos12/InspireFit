import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:inspirefit/models/models.dart';
import 'package:inspirefit/repositories/catalog_repository.dart';
import 'package:inspirefit/repositories/report_repository.dart';
import 'package:inspirefit/repositories/training_plan_repository.dart';
import 'package:inspirefit/repositories/training_session_repository.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Garante banco limpo para os seeds rodarem no onCreate.
    final dir = await databaseFactory.getDatabasesPath();
    final f = File('$dir/inspirefit.db');
    if (await f.exists()) await f.delete();
  });

  test('seeds populam catálogos', () async {
    final catalog = CatalogRepository();
    final days = await catalog.getDays();
    final trainings = await catalog.getTrainings();
    final exercises = await catalog.getExercises();

    expect(days.length, 7);
    expect(days.first.name, 'Segunda-feira');
    expect(trainings.length, 7);
    expect(exercises.length, greaterThan(150));

    final superiores = await catalog.getExercises(type: 'superior');
    expect(superiores.every((e) => e.type == 'superior'), true);
    final supinos = await catalog.getExercises(name: 'Supino');
    expect(supinos.isNotEmpty, true);
  });

  test('fluxo ponta-a-ponta: ficha -> sessão -> edição -> relatório', () async {
    final catalog = CatalogRepository();
    final plans = TrainingPlanRepository();
    final sessions = TrainingSessionRepository();
    final reports = ReportRepository();

    final exercises = await catalog.getExercises(type: 'superior');
    final exIds = exercises.take(3).map((e) => e.id).toList();

    // Cria ficha em "Segunda-feira" (day_id=1) / "Treino 1" (training_id=1).
    final planId = await plans.createPlan(
      trainingId: 1,
      dayId: 1,
      exerciseIds: exIds,
    );
    final planExercises = await plans.getPlanExercises(planId);
    expect(planExercises.length, 3);

    // Duas sessões em segundas diferentes para gerar progresso.
    final s1 = await sessions.createSession(
      planId: planId,
      performedDate: DateTime(2026, 5, 4),
      executions: [
        for (final pe in planExercises)
          ExecutionInput(
              trainingPlanExerciseId: pe.id,
              setsDone: 3,
              reps: 10,
              weight: 20),
      ],
    );
    await sessions.createSession(
      planId: planId,
      performedDate: DateTime(2026, 5, 11),
      executions: [
        for (final pe in planExercises)
          ExecutionInput(
              trainingPlanExerciseId: pe.id,
              setsDone: 3,
              reps: 12,
              weight: 25),
      ],
    );

    // Lê e edita as execuções da primeira sessão.
    final execs = await sessions.getSessionExecutions(s1);
    expect(execs.length, 3);
    expect(execs.first.weight, 20);
    await sessions.updateExecutions([
      ExecutionInfo(
        id: execs.first.id,
        trainingPlanExerciseId: execs.first.trainingPlanExerciseId,
        exerciseName: execs.first.exerciseName,
        setsDone: 4,
        reps: 11,
        weight: 22,
      ),
    ]);
    final reread = await sessions.getSessionExecutions(s1);
    expect(reread.first.weight, 22);
    expect(reread.first.setsDone, 4);

    // Aderência: ambas as sessões caíram na segunda (dia certo).
    final adherence = await reports.getPlanAdherence(
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 31),
    );
    final mine = adherence.firstWhere((a) => a.trainingPlanId == planId);
    expect(mine.doneRightDay, 2);
    expect(mine.dayName, 'Segunda-feira');

    // Progresso: deve haver evolução de carga.
    final progress = await reports.getExerciseProgress(
      planId,
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 31),
    );
    expect(progress.length, 3);
    expect(progress.first.timesPerformed, 2);
    // Exercícios 2 e 3 não foram editados: 20kg -> 25kg, evolução positiva.
    final unedited = progress[1];
    expect(unedited.timesPerformed, 2);
    expect(unedited.improvementPercentage, isNotNull);
    expect(unedited.improvementPercentage! > 0, true);

    // Deleta a ficha (cascade apaga sessões e execuções).
    await plans.deletePlan(planId);
    expect(await plans.getPlan(planId), isNull);
    final adherenceAfter = await reports.getPlanAdherence(
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 31),
    );
    expect(adherenceAfter.any((a) => a.trainingPlanId == planId), false);
  });
}
