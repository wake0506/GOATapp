import '../models/training.dart';

abstract interface class TrainingRepository {
  Future<void> saveSession(TrainingSession session);
}
