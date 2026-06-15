// Modelos de domínio do InspireFit. Espelham as tabelas do banco local
// (sem `user_id`, pois o app é offline e de usuário único) e alguns DTOs de
// view usados pelas telas.

class Day {
  final int id;
  final String name;
  const Day({required this.id, required this.name});

  factory Day.fromMap(Map<String, dynamic> m) =>
      Day(id: m['id'] as int, name: m['name'] as String);
}

class Training {
  final int id;
  final String name;
  const Training({required this.id, required this.name});

  factory Training.fromMap(Map<String, dynamic> m) =>
      Training(id: m['id'] as int, name: m['name'] as String);
}

class Exercise {
  final int id;
  final String name;
  final String type;
  const Exercise({required this.id, required this.name, required this.type});

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
        id: m['id'] as int,
        name: m['name'] as String,
        type: m['type'] as String,
      );
}

/// Ficha de treino (training_plan) já com os nomes resolvidos do treino e do dia.
class TrainingPlanInfo {
  final int id;
  final int trainingId;
  final int dayId;
  final String trainingName;
  final String dayName;

  const TrainingPlanInfo({
    required this.id,
    required this.trainingId,
    required this.dayId,
    required this.trainingName,
    required this.dayName,
  });

  factory TrainingPlanInfo.fromMap(Map<String, dynamic> m) => TrainingPlanInfo(
        id: m['id'] as int,
        trainingId: m['training_id'] as int,
        dayId: m['day_id'] as int,
        trainingName: m['training_name'] as String,
        dayName: m['day_name'] as String,
      );
}

/// Exercício pertencente a uma ficha (training_plan_exercise) com nome resolvido.
class PlanExercise {
  final int id; // training_plan_exercise.id
  final int trainingPlanId;
  final int exerciseId;
  final String exerciseName;
  final String exerciseType;

  const PlanExercise({
    required this.id,
    required this.trainingPlanId,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseType,
  });

  factory PlanExercise.fromMap(Map<String, dynamic> m) => PlanExercise(
        id: m['id'] as int,
        trainingPlanId: m['training_plan_id'] as int,
        exerciseId: m['exercise_id'] as int,
        exerciseName: m['exercise_name'] as String,
        exerciseType: m['exercise_type'] as String,
      );
}

/// Uma execução agregada de um exercício numa sessão (training_execution).
class ExecutionInput {
  final int trainingPlanExerciseId;
  final int setsDone;
  final double reps;
  final double weight;

  const ExecutionInput({
    required this.trainingPlanExerciseId,
    required this.setsDone,
    required this.reps,
    required this.weight,
  });
}

/// Execução já persistida, com nome do exercício (usada na edição de sessão).
class ExecutionInfo {
  final int id;
  final int trainingPlanExerciseId;
  final String exerciseName;
  final int? setsDone;
  final double? reps;
  final double? weight;

  const ExecutionInfo({
    required this.id,
    required this.trainingPlanExerciseId,
    required this.exerciseName,
    this.setsDone,
    this.reps,
    this.weight,
  });

  factory ExecutionInfo.fromMap(Map<String, dynamic> m) => ExecutionInfo(
        id: m['id'] as int,
        trainingPlanExerciseId: m['training_plan_exercise_id'] as int,
        exerciseName: m['exercise_name'] as String,
        setsDone: m['sets_done'] as int?,
        reps: (m['reps'] as num?)?.toDouble(),
        weight: (m['weight'] as num?)?.toDouble(),
      );
}

/// Resultado da checagem "existe sessão nesta semana para a ficha?".
class WeekSession {
  final bool exists;
  final int? sessionId;
  const WeekSession({required this.exists, this.sessionId});
}
