import 'package:flutter_tts/flutter_tts.dart';

import '../domain/i_speech_output.dart';

/// Infrastructure layer – Voice IO subsystem.
///
/// flutter_tts implementation of [ISpeechOutput] (Adapter).
class FlutterTtsSpeechOutput implements ISpeechOutput {
  final FlutterTts _tts;

  /// Slower than the default so stories are easy to follow.
  final double speechRate;
  bool _configured = false;

  FlutterTtsSpeechOutput({FlutterTts? tts, this.speechRate = 0.4})
      : _tts = tts ?? FlutterTts();

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(speechRate);
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    await _configure();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
