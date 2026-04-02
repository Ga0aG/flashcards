import 'dart:convert';
import 'package:localstorage/localstorage.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import 'spaced_repetition.dart';

class DatabaseService {
  final LocalStorage _storage = LocalStorage('flashcards.json');
  bool _initialized = false;

  Future<void> _init() async {
    if (!_initialized) {
      await _storage.ready;
      _initialized = true;
      if (_storage.getItem('wordbooks') == null) {
        _storage.setItem('wordbooks', []);
      }
      if (_storage.getItem('words') == null) {
        _storage.setItem('words', []);
      }
      if (_storage.getItem('settings') == null) {
        _storage.setItem('settings', {'main_language': 'zh-CN', 'default_review_count': '20'});
      }
    }
  }

  // WordBook CRUD
  Future<void> insertWordBook(WordBook wordbook) async {
    await _init();
    List<dynamic> books = _storage.getItem('wordbooks') ?? [];
    books.add(wordbook.toMap());
    _storage.setItem('wordbooks', books);
  }

  Future<List<WordBook>> getAllWordBooks() async {
    await _init();
    List<dynamic> books = _storage.getItem('wordbooks') ?? [];
    return books.map((map) => WordBook.fromMap(Map<String, dynamic>.from(map))).toList();
  }

  Future<void> deleteWordBook(String id) async {
    await _init();
    List<dynamic> books = _storage.getItem('wordbooks') ?? [];
    books.removeWhere((b) => b['id'] == id);
    _storage.setItem('wordbooks', books);

    List<dynamic> words = _storage.getItem('words') ?? [];
    words.removeWhere((w) => w['wordbook_id'] == id);
    _storage.setItem('words', words);
  }

  // Word CRUD
  Future<void> insertWord(Word word) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    words.add(word.toMap());
    _storage.setItem('words', words);
  }

  Future<List<Word>> getWordsByBookId(String bookId) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    return words
        .where((w) => w['wordbook_id'] == bookId)
        .map((map) => Word.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> updateWordMemoryLevel(String wordId, int newLevel, {bool updateCorrectTime = true}) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    for (var w in words) {
      if (w['id'] == wordId) {
        w['memory_level'] = newLevel;
        if (updateCorrectTime) {
          w['last_correct_at'] = DateTime.now().millisecondsSinceEpoch;
        }
        break;
      }
    }
    _storage.setItem('words', words);
  }

  Future<void> promoteWordMemoryLevel(String wordId) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    for (var w in words) {
      if (w['id'] == wordId) {
        final nextLevel = SpacedRepetitionService.nextLevel(w['memory_level'] as int);
        w['memory_level'] = nextLevel;
        w['last_correct_at'] = DateTime.now().millisecondsSinceEpoch;
        break;
      }
    }
    _storage.setItem('words', words);
  }

  Future<void> updateWord(Word word) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    for (int i = 0; i < words.length; i++) {
      if (words[i]['id'] == word.id) {
        words[i] = word.toMap();
        break;
      }
    }
    _storage.setItem('words', words);
  }

  Future<void> deleteWord(String id) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    words.removeWhere((w) => w['id'] == id);
    _storage.setItem('words', words);
  }

  // Settings
  Future<String?> getSetting(String key) async {
    await _init();
    Map<String, dynamic> settings = Map<String, dynamic>.from(_storage.getItem('settings') ?? {});
    return settings[key];
  }

  Future<void> setSetting(String key, String value) async {
    await _init();
    Map<String, dynamic> settings = Map<String, dynamic>.from(_storage.getItem('settings') ?? {});
    settings[key] = value;
    _storage.setItem('settings', settings);
  }
}
