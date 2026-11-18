/// Domain layer – Memory Domain subsystem.
///
/// Abstraction for spoken output, implemented in the Infrastructure layer
/// (Voice IO) by FlutterTtsSpeechOutput.
abstract class ISpeechOutput {
  Future<void> speak(String text);

  Future<void> stop();
}
