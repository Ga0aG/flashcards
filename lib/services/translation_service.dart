import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static const _timeout = Duration(seconds: 2);

  /// Translates [word] to [targetLang] (e.g. 'zh-CN', 'en').
  /// Returns null on failure.
  Future<String?> translate(String word, String targetLang) async {
    try {
      final langPair = 'en|${targetLang.split('-').first}';
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(word)}&langpair=$langPair',
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translated = data['responseData']?['translatedText'] as String?;
        if (translated != null && translated.isNotEmpty && translated != word) {
          return translated;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches an example sentence for [word] from Tatoeba via CORS proxy.
  /// Returns null on failure.
  Future<String?> getExampleSentence(String word) async {
    try {
      // Use corsproxy.io to bypass CORS restrictions in web builds
      final targetUrl = Uri.encodeComponent(
        'https://tatoeba.org/en/api_v0/search?query=${Uri.encodeComponent(word)}&from=eng&to=und&orphans=no&unapproved=no&native=yes&trans_filter=limit&trans_to=cmn&sort=relevance',
      );
      final uri = Uri.parse('https://corsproxy.io/?url=$targetUrl');
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final sentence = results.first['text'] as String?;
          if (sentence != null && sentence.isNotEmpty) {
            return sentence;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
