import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localstorage/localstorage.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import 'spaced_repetition.dart';

class DatabaseService {
  // 单例
  DatabaseService._internal();
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  final LocalStorage _storage = LocalStorage('flashcards.json');
  bool _initialized = false;

  // Firestore 引用（登录后由 AuthProvider 注入）
  String? _uid;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  CollectionReference? get _wordbooksRef =>
      _uid != null ? _firestore.collection('users/$_uid/wordbooks') : null;
  CollectionReference? get _wordsRef =>
      _uid != null ? _firestore.collection('users/$_uid/words') : null;
  DocumentReference? get _settingsRef =>
      _uid != null ? _firestore.doc('users/$_uid/settings') : null;

  void setFirestoreUser(String? uid) {
    _uid = uid;
  }

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

  // ─── WordBook CRUD ────────────────────────────────────────────────

  Future<void> insertWordBook(WordBook wordbook) async {
    await _init();
    List<dynamic> books = _storage.getItem('wordbooks') ?? [];
    books.add(wordbook.toMap());
    _storage.setItem('wordbooks', books);
    _wordbooksRef?.doc(wordbook.id).set(wordbook.toFirestoreMap());
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

    // Firestore 软删除
    final now = DateTime.now().millisecondsSinceEpoch;
    _wordbooksRef?.doc(id).update({'deleted': true, 'updated_at': now});
    // 级联软删除该单词本下的所有单词
    _wordsRef?.where('wordbook_id', isEqualTo: id).get().then((snap) {
      for (final doc in snap.docs) {
        doc.reference.update({'deleted': true, 'updated_at': now});
      }
    });
  }

  // 供 SyncService 使用：仅删除本地，不触发 Firestore
  Future<void> deleteWordBookLocal(String id) async {
    await _init();
    List<dynamic> books = _storage.getItem('wordbooks') ?? [];
    books.removeWhere((b) => b['id'] == id);
    _storage.setItem('wordbooks', books);

    List<dynamic> words = _storage.getItem('words') ?? [];
    words.removeWhere((w) => w['wordbook_id'] == id);
    _storage.setItem('words', words);
  }

  // 供 SyncService 使用：upsert（存在则覆盖，不存在则插入）
  Future<void> upsertWordBook(WordBook wordbook) async {
    await _init();
    List<dynamic> books = _storage.getItem('wordbooks') ?? [];
    final idx = books.indexWhere((b) => b['id'] == wordbook.id);
    if (idx >= 0) {
      books[idx] = wordbook.toMap();
    } else {
      books.add(wordbook.toMap());
    }
    _storage.setItem('wordbooks', books);
  }

  // ─── Word CRUD ────────────────────────────────────────────────────

  Future<void> insertWord(Word word) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    words.add(word.toMap());
    _storage.setItem('words', words);
    _wordsRef?.doc(word.id).set(word.toFirestoreMap());
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

  Future<void> updateWordMemoryLevel(String wordId, int newLevel,
      {bool updateCorrectTime = true}) async {
    await _init();
    final now = DateTime.now().millisecondsSinceEpoch;
    List<dynamic> words = _storage.getItem('words') ?? [];
    for (var w in words) {
      if (w['id'] == wordId) {
        w['memory_level'] = newLevel;
        if (updateCorrectTime) {
          w['last_correct_at'] = now;
        }
        break;
      }
    }
    _storage.setItem('words', words);
    _wordsRef?.doc(wordId).update({
      'memory_level': newLevel,
      if (updateCorrectTime) 'last_correct_at': now,
      'updated_at': now,
    });
  }

  Future<void> promoteWordMemoryLevel(String wordId) async {
    await _init();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    List<dynamic> words = _storage.getItem('words') ?? [];
    int newLevel = 1;
    for (var w in words) {
      if (w['id'] == wordId) {
        final lastCorrectAt = w['last_correct_at'] as int? ?? 0;
        final lastDay = DateTime.fromMillisecondsSinceEpoch(lastCorrectAt);
        final sameDay = lastCorrectAt > 0 &&
            lastDay.year == now.year &&
            lastDay.month == now.month &&
            lastDay.day == now.day;
        if (!sameDay) {
          w['memory_level'] = SpacedRepetitionService.nextLevel(w['memory_level'] as int);
        }
        w['last_correct_at'] = nowMs;
        newLevel = w['memory_level'] as int;
        break;
      }
    }
    _storage.setItem('words', words);
    _wordsRef?.doc(wordId).update({
      'memory_level': newLevel,
      'last_correct_at': nowMs,
      'updated_at': nowMs,
    });
  }

  Future<void> updateWord(Word word) async {
    await _init();
    final now = DateTime.now().millisecondsSinceEpoch;
    List<dynamic> words = _storage.getItem('words') ?? [];
    for (int i = 0; i < words.length; i++) {
      if (words[i]['id'] == word.id) {
        words[i] = word.toMap();
        break;
      }
    }
    _storage.setItem('words', words);
    final map = word.toFirestoreMap();
    map['updated_at'] = now;
    _wordsRef?.doc(word.id).set(map);
  }

  Future<void> deleteWord(String id) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    words.removeWhere((w) => w['id'] == id);
    _storage.setItem('words', words);
    final now = DateTime.now().millisecondsSinceEpoch;
    _wordsRef?.doc(id).update({'deleted': true, 'updated_at': now});
  }

  // 供 SyncService 使用：仅删除本地，不触发 Firestore
  Future<void> deleteWordLocal(String id) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    words.removeWhere((w) => w['id'] == id);
    _storage.setItem('words', words);
  }

  // 供 SyncService 使用：upsert word
  Future<void> upsertWord(Word word) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    final idx = words.indexWhere((w) => w['id'] == word.id);
    if (idx >= 0) {
      words[idx] = word.toMap();
    } else {
      words.add(word.toMap());
    }
    _storage.setItem('words', words);
  }

  // 供 SyncService 使用：云端数据合并到本地
  Future<void> mergeFromCloud(List<WordBook> cloudBooks, List<Word> cloudWords) async {
    await _init();

    final localBooks = await getAllWordBooks();
    final localBookMap = {for (final b in localBooks) b.id: b};
    for (final book in cloudBooks) {
      final local = localBookMap[book.id];
      if (local == null || local.updatedAt < book.updatedAt) {
        await upsertWordBook(book);
      }
    }

    // 删除本地有、云端没有（已软删除）的 wordbook
    final cloudBookIds = cloudBooks.map((b) => b.id).toSet();
    for (final local in localBooks) {
      if (!cloudBookIds.contains(local.id)) {
        await deleteWordBookLocal(local.id);
      }
    }

    // 合并 words
    final allLocalWords = <Word>[];
    final updatedBooks = await getAllWordBooks();
    for (final b in updatedBooks) {
      allLocalWords.addAll(await getWordsByBookId(b.id));
    }
    final localWordMap = {for (final w in allLocalWords) w.id: w};
    for (final word in cloudWords) {
      final local = localWordMap[word.id];
      if (local == null || local.lastCorrectAt < word.lastCorrectAt) {
        await upsertWord(word);
      }
    }

    final cloudWordIds = cloudWords.map((w) => w.id).toSet();
    for (final local in allLocalWords) {
      if (!cloudWordIds.contains(local.id)) {
        await deleteWordLocal(local.id);
      }
    }
  }

  // ─── Tag operations ───────────────────────────────────────────────

  Future<List<String>> getAllTags(String bookId) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    final tags = <String>{};
    for (var w in words) {
      if (w['wordbook_id'] == bookId) {
        final t = w['tags'];
        final tagStr = t is String ? t : '';
        for (var tag in tagStr.split(',')) {
          final trimmed = tag.trim();
          if (trimmed.isNotEmpty) tags.add(trimmed);
        }
      }
    }
    return tags.toList()..sort();
  }

  Future<void> renameTag(String bookId, String oldTag, String newTag) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var w in words) {
      if (w['wordbook_id'] == bookId) {
        final t = w['tags'];
        final tagStr = t is String ? t : '';
        final tagList = tagStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final idx = tagList.indexOf(oldTag);
        if (idx != -1) {
          tagList[idx] = newTag;
          w['tags'] = tagList.join(',');
          _wordsRef?.doc(w['id'] as String).update({
            'tags': tagList,
            'updated_at': now,
          });
        }
      }
    }
    _storage.setItem('words', words);
  }

  Future<void> deleteTag(String bookId, String tag) async {
    await _init();
    List<dynamic> words = _storage.getItem('words') ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var w in words) {
      if (w['wordbook_id'] == bookId) {
        final t = w['tags'];
        final tagStr = t is String ? t : '';
        final tagList = tagStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e != tag).toList();
        w['tags'] = tagList.join(',');
        _wordsRef?.doc(w['id'] as String).update({
          'tags': tagList,
          'updated_at': now,
        });
      }
    }
    _storage.setItem('words', words);
  }

  // ─── Settings ─────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    await _init();
    Map<String, dynamic> settings =
        Map<String, dynamic>.from(_storage.getItem('settings') ?? {});
    return settings[key];
  }

  Future<void> setSetting(String key, String value) async {
    await _init();
    Map<String, dynamic> settings =
        Map<String, dynamic>.from(_storage.getItem('settings') ?? {});
    settings[key] = value;
    _storage.setItem('settings', settings);
    _settingsRef?.update({key: value});
  }
}
