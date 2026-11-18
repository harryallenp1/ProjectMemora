import '../domain/i_memory_repository.dart';
import '../domain/i_speech_output.dart';
import '../domain/memory.dart';
import '../domain/mood_entry.dart';

/// Application layer – Memory Support Service subsystem.
///
/// Coordinates UC-03 Personalized Memory and Emotional Support. Depends only on
/// domain interfaces, never on Firestore or flutter_tts directly.
class MemorySupportService {
  final IMemoryRepository memoryRepository;
  final ISpeechOutput speechOutput;

  MemorySupportService({
    required this.memoryRepository,
    required this.speechOutput,
  });

  /// The patient's memories, newest first.
  Future<List<Memory>> getMemoriesForPatient(String patientId) async {
    final memories = await memoryRepository.findByPatient(patientId);
    memories.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return memories;
  }

  /// Caregiver adds a memory. Needs a patient, a person or title, and a story.
  Future<Memory> addMemory(Memory memory) {
    if (memory.patientId.trim().isEmpty) {
      throw ArgumentError('A memory must belong to a patient.');
    }
    if (memory.personName.trim().isEmpty && memory.title.trim().isEmpty) {
      throw ArgumentError('Add a person\'s name or a title.');
    }
    if (memory.story.trim().isEmpty) {
      throw ArgumentError('Add a short story for this memory.');
    }
    return memoryRepository.save(memory);
  }

  /// Reads the memory aloud to the patient.
  Future<void> narrateMemory(Memory memory) async {
    final text = memory.toNarration();
    if (text.isEmpty) return;
    await speechOutput.stop(); // never talk over a previous memory
    await speechOutput.speak(text);
  }

  /// Logs how the patient feels. If the mood needs comfort (anxious, sad...),
  /// returns a memory to show; otherwise returns null.
  Future<Memory?> recordMoodAndGetComfortMemory(
    String patientId,
    String mood, {
    DateTime? now,
  }) async {
    final entry = MoodEntry(
      patientId: patientId,
      mood: mood.trim().toLowerCase(),
      timestamp: now ?? DateTime.now(),
    );
    await memoryRepository.saveMood(entry);
    if (!entry.needsComfort) return null;

    final memories = await getMemoriesForPatient(patientId);
    if (memories.isEmpty) return null;
    // Prefer a memory about a familiar person, most recent first.
    return memories.firstWhere(
      (m) => m.personName.trim().isNotEmpty,
      orElse: () => memories.first,
    );
  }
}
