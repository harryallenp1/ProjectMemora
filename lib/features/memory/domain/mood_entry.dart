/// Domain layer – Memory Domain subsystem.
///
/// A mood the patient reported (e.g. happy, calm, anxious, sad).
class MoodEntry {
  /// Moods that should be answered with a comforting memory.
  static const Set<String> comfortMoods = {
    'anxious',
    'sad',
    'confused',
    'lonely',
    'scared',
  };

  final String? moodEntryId;
  final String patientId;
  final String mood;
  final DateTime timestamp;

  const MoodEntry({
    this.moodEntryId,
    required this.patientId,
    required this.mood,
    required this.timestamp,
  });

  bool get needsComfort => comfortMoods.contains(mood.trim().toLowerCase());

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'mood': mood,
        'timestamp': timestamp.toIso8601String(),
      };
}
