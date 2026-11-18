import '../domain/i_memory_repository.dart';
import '../domain/memory.dart';
import '../domain/mood_entry.dart';

/// Infrastructure layer – Persistence subsystem.
///
/// In-memory [IMemoryRepository] used by unit tests and when the app runs
/// without a Firebase project configured (see MemoryModule).
class InMemoryMemoryRepository implements IMemoryRepository {
  final Map<String, Memory> _memories = {};
  final List<MoodEntry> moods = [];
  int _nextId = 1;

  @override
  Future<List<Memory>> findByPatient(String patientId) async =>
      _memories.values.where((m) => m.patientId == patientId).toList();

  @override
  Future<Memory?> findById(String memoryId) async => _memories[memoryId];

  @override
  Future<Memory> save(Memory memory) async {
    final saved = memory.memoryId == null
        ? memory.copyWith(memoryId: 'memory-${_nextId++}')
        : memory;
    _memories[saved.memoryId!] = saved;
    return saved;
  }

  @override
  Future<void> saveMood(MoodEntry entry) async => moods.add(entry);
}
