
class PlanAdherence {
  final int trainingPlanId;
  final int trainingId;
  final int dayId;
  final String trainingName;
  final String dayName;
  final int plannedTotal;
  final int doneRightDay;
  final int doneEarly;
  final int doneWrongDay;
  final int notDone;

  const PlanAdherence({
    required this.trainingPlanId,
    required this.trainingId,
    required this.dayId,
    required this.trainingName,
    required this.dayName,
    required this.plannedTotal,
    required this.doneRightDay,
    required this.doneEarly,
    required this.doneWrongDay,
    required this.notDone,
  });

  int get doneTotal => doneRightDay + doneEarly + doneWrongDay;
}

class ExecutionStats {
  final int? setsDone;
  final double? reps;
  final double? weight;
  final String performedDate;

  const ExecutionStats({
    this.setsDone,
    this.reps,
    this.weight,
    required this.performedDate,
  });
}

class ExerciseProgress {
  final int exerciseId;
  final String exerciseName;
  final String exerciseType;
  final int timesPerformed;
  final int timesSkipped;
  final ExecutionStats? firstExecution;
  final ExecutionStats? bestExecution;
  final ExecutionStats? lastExecution;
  final String? improvementSummary;
  final double? improvementPercentage;

  const ExerciseProgress({
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseType,
    required this.timesPerformed,
    required this.timesSkipped,
    this.firstExecution,
    this.bestExecution,
    this.lastExecution,
    this.improvementSummary,
    this.improvementPercentage,
  });
}
