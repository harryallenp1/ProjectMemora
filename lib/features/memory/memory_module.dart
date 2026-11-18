import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'application/memory_support_service.dart';
import 'domain/i_memory_repository.dart';
import 'infrastructure/firestore_memory_repository.dart';
import 'infrastructure/flutter_tts_speech_output.dart';
import 'infrastructure/in_memory_memory_repository.dart';
import 'ui/memory_view_model.dart';

/// Composition root for UC-03: wires the infrastructure implementations into
/// the application service (dependency injection).
///
/// Firestore is used when the app is started with
///   flutter run --dart-define=USE_FIREBASE=true
/// after the Firebase project is configured (flutterfire configure).
/// Otherwise memories are kept in memory so the use case can be demoed.
class MemoryModule {
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

  static MemorySupportService? _service;

  static Future<void> init() async {
    IMemoryRepository repository = InMemoryMemoryRepository();
    if (useFirebase) {
      try {
        await Firebase.initializeApp();
        repository = FirestoreMemoryRepository();
      } catch (e) {
        debugPrint('Firebase unavailable, using in-memory memories: $e');
      }
    }
    _service = MemorySupportService(
      memoryRepository: repository,
      speechOutput: FlutterTtsSpeechOutput(),
    );
  }

  static MemorySupportService get service =>
      _service ??= MemorySupportService(
        memoryRepository: InMemoryMemoryRepository(),
        speechOutput: FlutterTtsSpeechOutput(),
      );

  static MemoryViewModel createViewModel() =>
      MemoryViewModel(memoryService: service);
}
