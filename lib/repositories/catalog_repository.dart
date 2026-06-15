import '../data/database_helper.dart';
import '../models/models.dart';

/// Leitura dos catálogos pré-cadastrados: dias, treinos e exercícios.
class CatalogRepository {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<Day>> getDays() async {
    final db = await _dbHelper.database;
    final rows = await db.query('days', orderBy: 'id');
    return rows.map(Day.fromMap).toList();
  }

  Future<List<Training>> getTrainings() async {
    final db = await _dbHelper.database;
    final rows = await db.query('trainings', orderBy: 'id');
    return rows.map(Training.fromMap).toList();
  }

  /// Lista exercícios com filtro opcional por nome (LIKE) e tipo.
  Future<List<Exercise>> getExercises({String? name, String? type}) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (name != null && name.trim().isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%${name.trim()}%');
    }
    if (type != null && type.isNotEmpty) {
      where.add('type = ?');
      args.add(type);
    }
    final rows = await db.query(
      'exercises',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name',
    );
    return rows.map(Exercise.fromMap).toList();
  }
}
