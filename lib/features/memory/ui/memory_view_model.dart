import 'package:flutter/foundation.dart';

import '../application/memory_support_service.dart';
import '../domain/memory.dart';
import '../domain/memory_reaction.dart';

/// UI layer – Patient Screens subsystem.
///
/// View model of the MVVM pair. Screens listen to it and rebuild when it calls
/// notifyListeners() (Observer).
class MemoryViewModel extends ChangeNotifier {
  final MemorySupportService memoryService;

  List<Memory> _memories = [];
  bool _isLoading = false;
  String? _errorMessage;
  Memory? _comfortMemory;

  MemoryViewModel({required this.memoryService});

  List<Memory> get memories => List.unmodifiable(_memories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Memory? get comfortMemory => _comfortMemory;

  Future<void> loadMemories(String patientId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _memories = await memoryService.getMemoriesForPatient(patientId);
    } catch (_) {
      _errorMessage = 'Could not load memories. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playStory(Memory memory) => memoryService.narrateMemory(memory);

  /// Returns true when the memory was saved.
  Future<bool> addMemory(Memory memory) async {
    _errorMessage = null;
    try {
      final saved = await memoryService.addMemory(memory);
      _memories = [saved, ..._memories];
      return true;
    } on ArgumentError catch (e) {
      _errorMessage = e.message?.toString();
      return false;
    } catch (_) {
      _errorMessage = 'Could not save the memory. Please try again.';
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Logs the mood; if the patient needs comfort, shows and reads a memory.
  Future<Memory?> recordMood(String patientId, String mood) async {
    _comfortMemory =
        await memoryService.recordMoodAndGetComfortMemory(patientId, mood);
    notifyListeners();
    final comfort = _comfortMemory;
    if (comfort != null) memoryService.narrateMemory(comfort);
    return comfort;
  }

  /// Saves the "Do you feel better?" answer the recommender learns from.
  Future<void> recordReaction(String patientId, Memory memory,
      String moodBefore, ReactionType reaction) async {
    try {
      await memoryService.recordReaction(
        patientId: patientId,
        memory: memory,
        moodBefore: moodBefore,
        reaction: reaction,
      );
    } catch (_) {
      // Feedback is best-effort; never interrupt the patient over it.
    }
  }

  /// Predicted difficult period: a memory to offer, or null.
  Future<ProactiveComfort?> checkProactiveComfort(String patientId) =>
      memoryService.checkProactiveComfort(patientId);
}
