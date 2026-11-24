import 'package:flutter/foundation.dart';

import '../domain/i_memory_repository.dart';
import '../domain/i_prediction_service.dart';
import '../domain/i_speech_output.dart';
import '../domain/memory.dart';
import '../domain/memory_reaction.dart';
import '../domain/mood_entry.dart';

/// Application layer – Memory Support Service subsystem.
///
/// Coordinates UC-03 Personalized Memory and Emotional Support. Depends only on
/// domain interfaces, never on Firestore, flutter_tts or HTTP directly.
///
/// When an [IPredictionService] is configured, comfort memories are chosen by
/// the ML recommender and anxious periods are predicted. If it is missing or
/// fails (offline, timeout, cold start), the service falls back to simple
/// rules, so the patient is never left waiting.
class MemorySupportService {
  final IMemoryRepository memoryRepository;
  final ISpeechOutput speechOutput;
  final IPredictionService? predictionService;

  /// Proactive prompts are shown at most this often.
  final Duration promptCooldown;
  final Map<String, DateTime> _lastPrompt = {};

  /// How much mood history is sent to the model (it uses the last 7 days).
  static const Duration historyWindow = Duration(days: 8);

  MemorySupportService({
    required this.memoryRepository,
    required this.speechOutput,
    this.predictionService,
    this.promptCooldown = const Duration(hours: 2),
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
  /// returns the memory most likely to help; otherwise returns null.
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
    return chooseComfortMemory(patientId, entry.mood);
  }

  /// ML recommender first; rule-based fallback if it is unavailable.
  Future<Memory?> chooseComfortMemory(String patientId, String mood) async {
    final memories = await getMemoriesForPatient(patientId);
    if (memories.isEmpty) return null;

    final ml = predictionService;
    if (ml != null) {
      try {
        final reactions = await memoryRepository.findReactions(patientId);
        final ranked = await ml.rankMemories(
          patientId: patientId,
          mood: mood,
          memories: memories,
          reactions: reactions,
        );
        for (final id in ranked) {
          final match = memories.where((m) => m.memoryId == id);
          if (match.isNotEmpty) return match.first;
        }
      } catch (e) {
        debugPrint('Recommender unavailable, using fallback rule: $e');
      }
    }
    return _fallbackComfortMemory(memories);
  }

  /// Rule used before the ML service existed, and whenever it is unreachable:
  /// the newest memory about a familiar person.
  static Memory _fallbackComfortMemory(List<Memory> newestFirst) =>
      newestFirst.firstWhere(
        (m) => m.personName.trim().isNotEmpty,
        orElse: () => newestFirst.first,
      );

  /// Saves the patient's "Do you feel better?" answer. This is the feedback
  /// the recommender learns from.
  Future<void> recordReaction({
    required String patientId,
    required Memory memory,
    required String moodBefore,
    required ReactionType reaction,
    DateTime? now,
  }) async {
    final id = memory.memoryId;
    if (id == null) return;
    await memoryRepository.saveReaction(MemoryReaction(
      patientId: patientId,
      memoryId: id,
      moodBefore: moodBefore.trim().toLowerCase(),
      reaction: reaction,
      timestamp: now ?? DateTime.now(),
    ));
  }

  /// Alternate flow A1: if the model predicts a difficult hour, returns the
  /// prediction and a memory to offer. Returns null when risk is low, the
  /// service is unavailable, or the patient was prompted recently.
  Future<ProactiveComfort?> checkProactiveComfort(
    String patientId, {
    List<DateTime> missedRoutines = const [],
    DateTime? now,
  }) async {
    final ml = predictionService;
    if (ml == null) return null;
    final at = now ?? DateTime.now();
    final last = _lastPrompt[patientId];
    if (last != null && at.difference(last) < promptCooldown) return null;

    try {
      final moods = await memoryRepository.findMoods(patientId,
          since: at.subtract(historyWindow));
      final prediction = await ml.predictRisk(
        patientId: patientId,
        moods: moods,
        missedRoutines: missedRoutines,
        at: at,
      );
      if (!prediction.isHigh) return null;
      final memory = await chooseComfortMemory(patientId, 'anxious');
      if (memory == null) return null;
      _lastPrompt[patientId] = at;
      return ProactiveComfort(prediction: prediction, memory: memory);
    } catch (e) {
      debugPrint('Risk prediction unavailable: $e');
      return null;
    }
  }

  /// Caregiver insights screen. Returns null if the ML service is unavailable.
  Future<PatientInsights?> getInsights(
    String patientId, {
    List<DateTime> missedRoutines = const [],
    DateTime? now,
  }) async {
    final ml = predictionService;
    if (ml == null) return null;
    final at = now ?? DateTime.now();
    try {
      return await ml.getInsights(
        patientId: patientId,
        moods: await memoryRepository.findMoods(patientId,
            since: at.subtract(const Duration(days: 14))),
        memories: await getMemoriesForPatient(patientId),
        reactions: await memoryRepository.findReactions(patientId),
        missedRoutines: missedRoutines,
        at: at,
      );
    } catch (e) {
      debugPrint('Insights unavailable: $e');
      return null;
    }
  }
}

class ProactiveComfort {
  final RiskPrediction prediction;
  final Memory memory;
  const ProactiveComfort({required this.prediction, required this.memory});
}
