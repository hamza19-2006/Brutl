import '../models/brutl_models.dart';
import '../services/database_service.dart';

class WorkoutRepository {
  WorkoutRepository() : _databaseService = DatabaseService();

  final DatabaseService _databaseService;

  Future<void> saveExercise(ExerciseModel exercise) async {
    await _databaseService.saveExercise(exercise);
  }

  List<ExerciseModel> getExercisesForSplit(String splitName) {
    return _databaseService.getExercisesForSplit(splitName);
  }

  Future<void> syncPendingExercises() async {
    await _databaseService.syncPendingExercises();
  }

  Future<DateTime?> getLatestUpdatedAtForSplit(String splitName) {
    return _databaseService.getLatestUpdatedAtForSplit(splitName);
  }
}
