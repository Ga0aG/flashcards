import 'dart:js' as js;

// 短语言码 → BCP 47
const _langMap = {
  'ja': 'ja-JP',
  'en': 'en-US',
  'zh': 'zh-CN',
  'it': 'it-IT',
  'es': 'es-ES',
};

void speak(String text, String language) {
  final lang = _langMap[language] ?? language;
  final synth = js.context['speechSynthesis'];

  synth.callMethod('cancel');

  void doSpeak() {
    final utterance = js.JsObject(
      js.context['SpeechSynthesisUtterance'] as js.JsFunction,
      [text],
    );
    utterance['lang'] = lang;
    utterance['rate'] = 0.9;
    synth.callMethod('speak', [utterance]);
  }

  // Chrome bug: getVoices() 初次为空，需等 voiceschanged 后再播
  final voices = synth.callMethod('getVoices') as js.JsArray;
  if (voices.length > 0) {
    doSpeak();
  } else {
    synth['onvoiceschanged'] = js.allowInterop((_) {
      synth['onvoiceschanged'] = null;
      doSpeak();
    });
  }
}

void stop() {
  js.context['speechSynthesis'].callMethod('cancel');
}
