import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../screens/add_item_screen.dart';
import 'package:memora_app/models/user.dart';

class VoiceCommandWidget extends StatefulWidget {
  final User user;

  const VoiceCommandWidget({super.key, required this.user});

  @override
  State<VoiceCommandWidget> createState() => _VoiceCommandWidgetState();
}

class _VoiceCommandWidgetState extends State<VoiceCommandWidget> {
  late stt.SpeechToText _speech;
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _command = 'Tap mic and say something...';
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('STATUS: $status'),
        onError: (error) => print('ERROR: $error'),
      );

      if (available) {
        setState(() => _isListening = true);
        print("🎙️ Listening started...");

        _speech.listen(onResult: (result) {
          setState(() {
            _command = result.recognizedWords;
            print("🗣️ Heard: $_command");

            if (!_hasNavigated &&
                result.finalResult &&
                _command.toLowerCase().contains('add')) {
              _hasNavigated = true; // Prevent multiple navigations
              _tts.speak("Sure! Let's add an item.");

              Future.delayed(const Duration(seconds: 1), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddItemScreen(user: widget.user),
                  ),
                );
              });
            }
          });
        });
      } else {
        print("🚫 Speech recognition not available.");
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      print("🛑 Listening stopped.");
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
