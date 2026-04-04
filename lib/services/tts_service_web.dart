import 'dart:js' as js;

const _langMap = {
  'ja': 'ja-JP',
  'en': 'en-US',
  'zh': 'zh-CN',
  'it': 'it-IT',
  'es': 'es-ES',
};

void speak(String text, String language) {
  final lang = _langMap[language] ?? language;
  js.context.callMethod('ttsSpeak', [text, lang]);
}

void stop() {
  js.context.callMethod('ttsStop', []);
}
