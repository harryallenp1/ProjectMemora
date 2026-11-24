/// Domain layer – Memory Domain subsystem.
///
/// The patient's answer to "Do you feel better?" after a memory was played.
/// These answers are the training signal for the comfort memory recommender.
enum ReactionType { better, same, worse }

class MemoryReaction {
  final String patientId;
  final String memoryId;
  final String moodBefore;
  final ReactionType reaction;
  final DateTime timestamp;

  const MemoryReaction({
    required this.patientId,
    required this.memoryId,
    required this.moodBefore,
    required this.reaction,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'memoryId': memoryId,
        'moodBefore': moodBefore,
        'reaction': reaction.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MemoryReaction.fromMap(Map<String, dynamic> map) => MemoryReaction(
        patientId: (map['patientId'] ?? '') as String,
        memoryId: (map['memoryId'] ?? '') as String,
        moodBefore: (map['moodBefore'] ?? '') as String,
        reaction: ReactionType.values.firstWhere(
          (r) => r.name == map['reaction'],
          orElse: () => ReactionType.same,
        ),
        timestamp: DateTime.tryParse((map['timestamp'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
