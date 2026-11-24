import 'package:flutter_test/flutter_test.dart';
import 'package:memora_app/features/memory/application/memory_support_service.dart';
import 'package:memora_app/features/memory/domain/i_prediction_service.dart';
import 'package:memora_app/features/memory/domain/i_speech_output.dart';
import 'package:memora_app/features/memory/domain/memory.dart';
import 'package:memora_app/features/memory/domain/memory_reaction.dart';
import 'package:memora_app/features/memory/domain/mood_entry.dart';
import 'package:memora_app/features/memory/infrastructure/in_memory_memory_repository.dart';

/// Records what would have been spoken instead of using flutter_tts.
class FakeSpeechOutput implements ISpeechOutput {
  final List<String> spoken = [];
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls++;
}

/// Stands in for the Cloud Run ML API.
class FakePredictionService implements IPredictionService {
  List<String> ranking = [];
  RiskPrediction risk = const RiskPrediction(risk: 0.1, isHigh: false);
  bool fail = false;
  int riskCalls = 0;
  List<MemoryReaction>? lastReactions;

  void _maybeFail() {
    if (fail) throw Exception('service unavailable');
  }

  @override
  Future<RiskPrediction> predictRisk({
    required String patientId,
    required List<MoodEntry> moods,
    List<DateTime> missedRoutines = const [],
    DateTime? at,
  }) async {
    riskCalls++;
    _maybeFail();
    return risk;
  }

  @override
  Future<List<String>> rankMemories({
    required String patientId,
    required String mood,
    required List<Memory> memories,
    required List<MemoryReaction> reactions,
  }) async {
    _maybeFail();
    lastReactions = reactions;
    return ranking;
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
    _maybeFail();
    return const PatientInsights(
        riskByHour: [], peakHour: null, upsetByTimeOfDay: [],
        bestMemories: [], summary: []);
  }
}

Memory memoryFor(
  String patientId, {
  String title = 'Wedding day',
  String personName = 'Anna',
  String relationship = 'daughter',
  String story = 'You walked her down the aisle',
  DateTime? dateAdded,
}) =>
    Memory(
      patientId: patientId,
      title: title,
      personName: personName,
      relationship: relationship,
      story: story,
      createdBy: 'Caregiver',
      dateAdded: dateAdded ?? DateTime(2026, 1, 1),
    );

void main() {
  late InMemoryMemoryRepository repository;
  late FakeSpeechOutput speech;
  late MemorySupportService service;

  setUp(() {
    repository = InMemoryMemoryRepository();
    speech = FakeSpeechOutput();
    service = MemorySupportService(
      memoryRepository: repository,
      speechOutput: speech,
    );
  });

  group('Memory.toNarration', () {
    test('introduces the person, then the title and story', () {
      expect(
        memoryFor('1').toNarration(),
        'This is Anna, your daughter. Wedding day. You walked her down the aisle.',
      );
    });

    test('skips empty parts and does not double punctuation', () {
      final memory = memoryFor('1',
          personName: '', relationship: '', title: 'Trip to Kerala!');
      expect(memory.toNarration(),
          'Trip to Kerala! You walked her down the aisle.');
    });
  });

  group('getMemoriesForPatient', () {
    test('returns only that patient\'s memories, newest first', () async {
      await service.addMemory(memoryFor('1', title: 'Old', dateAdded: DateTime(2025)));
      await service.addMemory(memoryFor('1', title: 'New', dateAdded: DateTime(2026)));
      await service.addMemory(memoryFor('2', title: 'Other patient'));

      final memories = await service.getMemoriesForPatient('1');

      expect(memories.map((m) => m.title), ['New', 'Old']);
    });
  });

  group('addMemory', () {
    test('assigns an id when saved', () async {
      final saved = await service.addMemory(memoryFor('1'));
      expect(saved.memoryId, isNotNull);
    });

    test('rejects a memory without a story', () {
      expect(() => service.addMemory(memoryFor('1', story: '  ')),
          throwsArgumentError);
    });

    test('rejects a memory without a person or title', () {
      expect(
          () => service.addMemory(memoryFor('1', personName: '', title: '')),
          throwsArgumentError);
    });
  });

  group('narrateMemory', () {
    test('stops any current speech, then speaks the narration', () async {
      final memory = memoryFor('1');
      await service.narrateMemory(memory);

      expect(speech.stopCalls, 1);
      expect(speech.spoken, [memory.toNarration()]);
    });
  });

  group('recordMoodAndGetComfortMemory', () {
    test('saves the mood and returns a comfort memory when anxious', () async {
      await service.addMemory(memoryFor('1'));

      final comfort = await service.recordMoodAndGetComfortMemory('1', 'Anxious');

      expect(repository.moods.single.mood, 'anxious');
      expect(comfort?.personName, 'Anna');
    });

    test('saves the mood but returns nothing when happy', () async {
      await service.addMemory(memoryFor('1'));

      final comfort = await service.recordMoodAndGetComfortMemory('1', 'Happy');

      expect(repository.moods, hasLength(1));
      expect(comfort, isNull);
    });

    test('returns nothing when the patient has no memories', () async {
      final comfort = await service.recordMoodAndGetComfortMemory('1', 'sad');
      expect(comfort, isNull);
    });
  });

  group('ML prediction service', () {
    late FakePredictionService ml;
    late MemorySupportService mlService;
    final now = DateTime(2026, 11, 23, 16, 30);

    setUp(() {
      ml = FakePredictionService();
      mlService = MemorySupportService(
        memoryRepository: repository,
        speechOutput: speech,
        predictionService: ml,
      );
    });

    test('comfort memory follows the recommender ranking', () async {
      final anna = await mlService.addMemory(memoryFor('1', personName: 'Anna'));
      final ravi = await mlService.addMemory(memoryFor('1', personName: 'Ravi'));
      ml.ranking = [ravi.memoryId!, anna.memoryId!];

      final comfort = await mlService.recordMoodAndGetComfortMemory('1', 'anxious');

      expect(comfort?.personName, 'Ravi');
    });

    test('falls back to the rule when the service fails', () async {
      await mlService.addMemory(memoryFor('1', personName: 'Anna'));
      ml.fail = true;

      final comfort = await mlService.recordMoodAndGetComfortMemory('1', 'sad');

      expect(comfort?.personName, 'Anna');
      expect(repository.moods, hasLength(1));
    });

    test('reactions are saved and sent to the recommender', () async {
      final anna = await mlService.addMemory(memoryFor('1'));
      await mlService.recordReaction(
          patientId: '1', memory: anna, moodBefore: 'Anxious',
          reaction: ReactionType.better, now: now);

      await mlService.chooseComfortMemory('1', 'anxious');

      expect(repository.reactions.single.moodBefore, 'anxious');
      expect(ml.lastReactions?.single.reaction, ReactionType.better);
    });

    test('high predicted risk offers a memory, then waits before asking again',
        () async {
      await mlService.addMemory(memoryFor('1'));
      ml.risk = const RiskPrediction(
          risk: 0.7, isHigh: true, reasons: ['Late afternoon']);

      final first = await mlService.checkProactiveComfort('1', now: now);
      final second = await mlService.checkProactiveComfort('1',
          now: now.add(const Duration(minutes: 30)));
      final later = await mlService.checkProactiveComfort('1',
          now: now.add(const Duration(hours: 3)));

      expect(first?.memory.personName, 'Anna');
      expect(first?.prediction.reasons, ['Late afternoon']);
      expect(second, isNull);
      expect(later, isNotNull);
    });

    test('low risk or no service means no proactive prompt', () async {
      await mlService.addMemory(memoryFor('1'));
      expect(await mlService.checkProactiveComfort('1', now: now), isNull);
      expect(await service.checkProactiveComfort('1', now: now), isNull);
    });

    test('only the last week of moods is sent for prediction', () async {
      await repository.saveMood(MoodEntry(
          patientId: '1', mood: 'anxious',
          timestamp: now.subtract(const Duration(days: 30))));
      await repository.saveMood(MoodEntry(
          patientId: '1', mood: 'calm',
          timestamp: now.subtract(const Duration(days: 1))));

      final recent = await repository.findMoods('1',
          since: now.subtract(MemorySupportService.historyWindow));

      expect(recent.map((m) => m.mood), ['calm']);
    });
  });
}
