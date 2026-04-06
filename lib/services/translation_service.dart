import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class TranslationService {
  static const _timeout = Duration(seconds: 5);

  static const _tatoebaLang = {
    'ja': 'jpn',
    'en': 'eng',
    'zh': 'cmn',
    'it': 'ita',
    'es': 'spa',
  };

  /// Translates [word] from [sourceLang] (e.g. 'ja') to [targetLang] (e.g. 'zh-CN').
  /// Uses MyMemory matches sorted by usage-count to get the best quality translation.
  /// Returns null on failure.
  Future<String?> translate(String word, String sourceLang, String targetLang) async {
    try {
      final src = sourceLang.split('-').first;
      final tgt = targetLang.split('-').first;
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(word)}&langpair=$src|$tgt',
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);

      // Pick the match with highest usage-count for better quality
      final matches = data['matches'] as List?;
      if (matches != null && matches.isNotEmpty) {
        final sorted = List.of(matches)
          ..sort((a, b) => (int.tryParse(b['usage-count']?.toString() ?? '0') ?? 0)
              .compareTo(int.tryParse(a['usage-count']?.toString() ?? '0') ?? 0));
        final best = sorted.first['translation'] as String?;
        if (best != null && best.isNotEmpty && best != word) {
          return best;
        }
      }

      // Fallback to responseData
      final translated = data['responseData']?['translatedText'] as String?;
      if (translated != null && translated.isNotEmpty && translated != word) {
        return translated;
      }
    } catch (e) {
      print('[TranslationService.translate] error: $e');
    }
    return null;
  }

  /// Fetches an example sentence for [word] in [sourceLang] from Tatoeba.
  /// Japanese uses massif.la (has CORS). Others use Tatoeba directly (native)
  /// or via allorigins proxy (web).
  /// Returns null on failure.
  Future<String?> getExampleSentence(String word, String sourceLang) async {
    try {
      if (sourceLang == 'ja') {
        return await _getJapaneseSentence(word);
      }
      return await _getTatoebaSentence(word, sourceLang);
    } catch (e) {
      print('[TranslationService.getExampleSentence] error: $e');
    }
    return null;
  }

  /// Fetches Japanese example sentence from massif.la (supports CORS).
  Future<String?> _getJapaneseSentence(String word) async {
    final uri = Uri.parse(
      'https://massif.la/ja/search?q=${Uri.encodeComponent(word)}&fmt=json',
    );
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) return null;
    // Strip HTML tags from highlighted_html
    final html = results.first['highlighted_html'] as String?;
    if (html == null || html.isEmpty) return null;
    return html.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  /// Fetches example sentence from Tatoeba.
  /// Native: direct request. Web: via allorigins proxy (works for ASCII queries).
  Future<String?> _getTatoebaSentence(String word, String sourceLang) async {
    final fromLang = _tatoebaLang[sourceLang] ?? 'eng';
    final tatoebaPath =
        'https://tatoeba.org/en/api_v0/search?query=${Uri.encodeComponent(word)}&from=$fromLang&to=und&orphans=no&unapproved=no&native=yes&sort=relevance';

    http.Response response;
    dynamic data;

    if (kIsWeb) {
      final proxyUrl = 'https://api.allorigins.win/get?url=$tatoebaPath';
      response = await http.get(Uri.parse(proxyUrl)).timeout(_timeout);
      final wrapper = json.decode(response.body);
      final contents = wrapper['contents'] as String?;
      if (contents == null || contents.isEmpty) return null;
      data = json.decode(contents);
    } else {
      response = await http.get(Uri.parse(tatoebaPath)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      data = json.decode(response.body);
    }

    return _extractSentence(data);
  }

  String? _extractSentence(dynamic data) {
    final results = data['results'] as List?;
    if (results != null && results.isNotEmpty) {
      final sentence = results.first['text'] as String?;
      if (sentence != null && sentence.isNotEmpty) return sentence;
    }
    return null;
  }

  /// Returns pronunciation string for [word] in [sourceLang].
  /// Japanese → hiragana (Jotoba API).
  /// English → IPA phonetic (dictionaryapi.dev).
  /// Others → null.
  Future<String?> getPronunciation(String word, String sourceLang) async {
    try {
      final lang = sourceLang.split('-').first;
      if (lang == 'ja') return await _getJapanesePronunciation(word);
      if (lang == 'en') return await _getEnglishPronunciation(word);
    } catch (e) {
      print('[TranslationService.getPronunciation] error: $e');
    }
    return null;
  }

  /// Fetches hiragana reading from Jotoba.
  Future<String?> _getJapanesePronunciation(String word) async {
    final uri = Uri.parse('https://jotoba.de/api/search/words');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'query': word, 'language': 'Japanese', 'no_english': false}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    final words = data['words'] as List?;
    if (words == null || words.isEmpty) return null;
    // 取第一个词条的第一个读音
    final reading = words.first['reading'] as Map?;
    if (reading == null) return null;
    final kana = reading['kana'] as String?;
    return kana?.isNotEmpty == true ? kana : null;
  }

  /// Fetches IPA phonetic from dictionaryapi.dev.
  Future<String?> _getEnglishPronunciation(String word) async {
    final uri = Uri.parse(
        'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}');
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as List?;
    if (data == null || data.isEmpty) return null;
    final phonetics = data.first['phonetics'] as List?;
    if (phonetics == null || phonetics.isEmpty) return null;
    // 找第一个有 text 的音标
    for (final p in phonetics) {
      final text = p['text'] as String?;
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
