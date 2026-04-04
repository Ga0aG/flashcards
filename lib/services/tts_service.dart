import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service_web.dart' if (dart.library.io) 'tts_service_stub.dart'
    as web_tts;

class TtsService {
  final FlutterTts? _flutterTts = kIsWeb ? null : FlutterTts();

  void speak(String text, String language) {
    if (text.isEmpty) return;
    if (kIsWeb) {
      web_tts.speak(text, language);
    } else {
      _flutterTts!.setLanguage(language).then((_) => _flutterTts!.speak(text));
    }
  }

  void stop() {
    if (kIsWeb) {
      web_tts.stop();
    } else {
      _flutterTts!.stop();
    }
  }
}
