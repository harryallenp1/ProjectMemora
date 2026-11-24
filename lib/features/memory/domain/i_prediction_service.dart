import 'memory.dart';
import 'memory_reaction.dart';
import 'mood_entry.dart';

/// Domain layer – Memory Domain subsystem.
///
/// The ML Prediction Service (Cloud Run) as the domain sees it. The
/// infrastructure layer implements it over HTTP (Dependency Inversion), so the
/// application layer can be tested with a fake and falls back to simple rules
/// when the service is unreachable.
abstract class IPredictionService {
  /// Chance that the patient is upset in the next hour.
  Future<RiskPrediction> predictRisk({
    required String patientId,
    required List<MoodEntry> moods,
    List<DateTime> missedRoutines = const [],
    DateTime? at,
  });

  /// Memory ids, best first, for a patient who reported [mood].
  Future<List<String>> rankMemories({
    required String patientId,
    required String mood,
    required List<Memory> memories,
    required List<MemoryReaction> reactions,
  });

  /// Data for the caregiver insights screen.
  Future<PatientInsights> getInsights({
    required String patientId,
    required List<MoodEntry> moods,
    required List<Memory> memories,
    required List<MemoryReaction> reactions,
    List<DateTime> missedRoutines = const [],
    DateTime? at,
  });
}

class RiskPrediction {
  final double risk; // 0..1
  final bool isHigh;
  final List<String> reasons;

  const RiskPrediction({
    required this.risk,
    required this.isHigh,
    this.reasons = const [],
  });
}

class HourRisk {
  final int hour;
  final double risk;
  const HourRisk(this.hour, this.risk);
}

class PeriodShare {
  final String period;
  final double upsetShare;
  final int checkIns;
  const PeriodShare(this.period, this.upsetShare, this.checkIns);
}

class RankedMemory {
  final String memoryId;
  final double expectedHelp;
  final String reason;
  const RankedMemory(this.memoryId, this.expectedHelp, this.reason);
}

class PatientInsights {
  final List<HourRisk> riskByHour;
  final int? peakHour;
  final List<PeriodShare> upsetByTimeOfDay;
  final List<RankedMemory> bestMemories;
  final List<String> summary;

  const PatientInsights({
    required this.riskByHour,
    required this.peakHour,
    required this.upsetByTimeOfDay,
    required this.bestMemories,
    required this.summary,
  });
}
