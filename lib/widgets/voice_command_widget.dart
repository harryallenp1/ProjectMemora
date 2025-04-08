import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCommandWidget extends StatefulWidget {
  @override
  _VoiceCommandWidgetState createState() => _VoiceCommandWidgetState();
}

class _VoiceCommandWidgetState extends State<VoiceCommandWidget> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _command = 'Tap mic and say something...';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _command = result.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
          onPressed: _listen,
          color: Colors.deepPurple,
          iconSize: 40,
        ),
        const SizedBox(height: 10),
        Text(
          _command,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
