import 'memory.dart';
import 'mood_entry.dart';

/// Domain layer – Memory Domain subsystem.
///
/// Repository interface. The domain owns the interface and the Infrastructure
/// layer implements it (Repository pattern + Dependency Inversion).
abstract class IMemoryRepository {
  Future<List<Memory>> findByPatient(String patientId);

  Future<Memory?> findById(String memoryId);

  /// Saves the memory and returns it with its generated [Memory.memoryId].
  Future<Memory> save(Memory memory);

  Future<void> saveMood(MoodEntry entry);
}
