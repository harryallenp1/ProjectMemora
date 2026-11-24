import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'application/memory_support_service.dart';
import 'domain/i_memory_repository.dart';
import 'domain/i_prediction_service.dart';
import 'infrastructure/firestore_memory_repository.dart';
import 'infrastructure/flutter_tts_speech_output.dart';
import 'infrastructure/http_prediction_service.dart';
import 'infrastructure/in_memory_memory_repository.dart';
import 'ui/memory_view_model.dart';

/// Composition root for UC-03: wires the infrastructure implementations into
/// the application service (dependency injection).
///
/// Firestore is used when the app is started with
///   flutter run --dart-define=USE_FIREBASE=true
/// after the Firebase project is configured (flutterfire configure).
/// Otherwise memories are kept in memory so the use case can be demoed.
///
/// The ML Prediction Service (Cloud Run) is used when started with
///   --dart-define=ML_API_URL=https://<service>.run.app
///   --dart-define=ML_API_KEY=<key>      (if the service requires one)
/// Without it, comfort memories are chosen by the fallback rule.
class MemoryModule {
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');
  static const String mlApiUrl = String.fromEnvironment('ML_API_URL');
  static const String mlApiKey = String.fromEnvironment('ML_API_KEY');

  static IPredictionService? _predictionService() => mlApiUrl.isEmpty
      ? null
      : HttpPredictionService(
          baseUrl: mlApiUrl,
          apiKey: mlApiKey.isEmpty ? null : mlApiKey,
        );

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
      predictionService: _predictionService(),
    );
  }

  static MemorySupportService get service =>
      _service ??= MemorySupportService(
        memoryRepository: InMemoryMemoryRepository(),
        speechOutput: FlutterTtsSpeechOutput(),
        predictionService: _predictionService(),
      );

  static MemoryViewModel createViewModel() =>
      MemoryViewModel(memoryService: service);
}
