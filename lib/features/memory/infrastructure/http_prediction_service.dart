import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/i_prediction_service.dart';
import '../domain/memory.dart';
import '../domain/memory_reaction.dart';
import '../domain/mood_entry.dart';

/// Infrastructure layer – ML Prediction Service client (Adapter).
///
/// Calls the Memora ML API on Google Cloud Run (see ml/app/main.py). Every
/// call has a short timeout; MemorySupportService catches any failure and
/// falls back to its rule-based choice, so the app never waits on the cloud.
class HttpPredictionService implements IPredictionService {
  final Uri baseUrl;
  final String? apiKey;
  final http.Client _client;
  final Duration timeout;

  HttpPredictionService({
    required String baseUrl,
    this.apiKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 3),
  })  : baseUrl = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          baseUrl.resolve(path),
          headers: {
            'Content-Type': 'application/json',
            if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw PredictionServiceException(
          '$path returned ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static List<Map<String, dynamic>> _moods(List<MoodEntry> moods) => moods
      .map((m) => {'timestamp': m.timestamp.toIso8601String(), 'mood': m.mood})
      .toList();

  static List<Map<String, dynamic>> _memories(List<Memory> memories) => memories
      .where((m) => m.memoryId != null)
      .map((m) => {'memoryId': m.memoryId, 'relationship': m.relationship})
      .toList();

  static List<Map<String, dynamic>> _reactions(List<MemoryReaction> reactions) =>
      reactions
          .map((r) => {'memoryId': r.memoryId, 'reaction': r.reaction.name})
          .toList();

  @override
  Future<RiskPrediction> predictRisk({
    required String patientId,
    required List<MoodEntry> moods,
    List<DateTime> missedRoutines = const [],
    DateTime? at,
  }) async {
    final json = await _post('v1/risk', {
      'patientId': patientId,
      'at': (at ?? DateTime.now()).toIso8601String(),
      'moods': _moods(moods),
      'missedRoutines': missedRoutines.map((t) => t.toIso8601String()).toList(),
    });
    return RiskPrediction(
      risk: (json['risk'] as num).toDouble(),
      isHigh: json['level'] == 'high',
      reasons: List<String>.from(json['reasons'] as List),
    );
  }

  @override
  Future<List<String>> rankMemories({
    required String patientId,
    required String mood,
    required List<Memory> memories,
    required List<MemoryReaction> reactions,
  }) async {
    final json = await _post('v1/recommend', {
      'patientId': patientId,
      'mood': mood,
      'memories': _memories(memories),
      'reactions': _reactions(reactions),
    });
    return (json['ranked'] as List)
        .map((r) => (r as Map<String, dynamic>)['memoryId'] as String)
        .toList();
  }

  @override
  Future<PatientInsights> getInsights({
    required String patientId,
    required List<MoodEntry> moods,
    required List<Memory> memories,
    required List<MemoryReaction> reactions,
    List<DateTime> missedRoutines = const [],
    DateTime? at,
  }) async {
    final json = await _post('v1/insights', {
      'patientId': patientId,
      'at': (at ?? DateTime.now()).toIso8601String(),
      'moods': _moods(moods),
      'missedRoutines': missedRoutines.map((t) => t.toIso8601String()).toList(),
      'memories': _memories(memories),
      'reactions': _reactions(reactions),
    });
    List<Map<String, dynamic>> list(String key) =>
        (json[key] as List).cast<Map<String, dynamic>>();
    return PatientInsights(
      riskByHour: list('riskByHour')
          .map((h) => HourRisk(h['hour'] as int, (h['risk'] as num).toDouble()))
          .toList(),
      peakHour: json['peakHour'] as int?,
      upsetByTimeOfDay: list('upsetByTimeOfDay')
          .map((p) => PeriodShare(p['period'] as String,
              (p['upsetShare'] as num).toDouble(), p['checkIns'] as int))
          .toList(),
      bestMemories: list('bestMemories')
          .map((m) => RankedMemory(m['memoryId'] as String,
              (m['expectedHelp'] as num).toDouble(), m['reason'] as String))
          .toList(),
      summary: List<String>.from(json['summary'] as List),
    );
  }
}

class PredictionServiceException implements Exception {
  final String message;
  PredictionServiceException(this.message);
  @override
  String toString() => 'PredictionServiceException: $message';
}
