import 'package:flutter_test/flutter_test.dart';
import 'package:memora_app/features/memory/application/memory_support_service.dart';
import 'package:memora_app/features/memory/domain/i_speech_output.dart';
import 'package:memora_app/features/memory/domain/memory.dart';
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
}
