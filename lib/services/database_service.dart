import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import '../models/scenario.dart';
import 'spaced_repetition.dart';

/// Firestore 为主存储的数据服务。
/// - 所有 CRUD 直接读写 Firestore（SDK 自带 IndexedDB 离线缓存）
/// - 设置项（Settings）继续放 SharedPreferences，本地优先
/// - 未登录时所有方法抛 [StateError]，由 UI 层拦截在登录页面
class DatabaseService {
  // 单例
  DatabaseService._internal();
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  String? _uid;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _wordbooksRef =>
      _firestore.collection('users/${_requireUid()}/wordbooks');
  CollectionReference<Map<String, dynamic>> get _wordsRef =>
      _firestore.collection('users/${_requireUid()}/words');
  CollectionReference<Map<String, dynamic>> get _scenariosRef =>
      _firestore.collection('users/${_requireUid()}/scenarios');
  DocumentReference<Map<String, dynamic>> get _settingsRef => _firestore
      .collection('users')
      .doc(_requireUid())
      .collection('meta')
      .doc('settings');

  String _requireUid() {
    final uid = _uid;
    if (uid == null) {
      throw StateError('未登录，无法访问数据');
    }
    return uid;
  }

  bool get isLoggedIn => _uid != null;

  void setFirestoreUser(String? uid) {
    _uid = uid;
  }

  // ─── WordBook CRUD ────────────────────────────────────────────────

  Future<void> insertWordBook(WordBook wordbook) async {
    await _wordbooksRef.doc(wordbook.id).set(wordbook.toFirestoreMap());
  }

  Future<List<WordBook>> getAllWordBooks() async {
    final snap = await _wordbooksRef
        .where('deleted', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs
        .map((d) => WordBook.fromFirestoreMap({'id': d.id, ...d.data()}))
        .toList();
  }

  Future<void> deleteWordBook(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _firestore.batch();
    batch.update(_wordbooksRef.doc(id), {'deleted': true, 'updated_at': now});
    // 级联软删除该单词本下的所有单词
    final wordsSnap =
        await _wordsRef.where('wordbook_id', isEqualTo: id).get();
    for (final doc in wordsSnap.docs) {
      batch.update(doc.reference, {'deleted': true, 'updated_at': now});
    }
    await batch.commit();
  }

  // ─── Word CRUD ────────────────────────────────────────────────────

  Future<void> insertWord(Word word) async {
    await _wordsRef.doc(word.id).set(word.toFirestoreMap());
  }

  Future<List<Word>> getWordsByBookId(String bookId) async {
    final snap = await _wordsRef
        .where('wordbook_id', isEqualTo: bookId)
        .where('deleted', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs
        .map((d) => Word.fromFirestoreMap({'id': d.id, ...d.data()}))
        .toList();
  }

  Future<void> updateWordMemoryLevel(String wordId, int newLevel,
      {bool updateCorrectTime = true}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _wordsRef.doc(wordId).update({
      'memory_level': newLevel,
      if (updateCorrectTime) 'last_correct_at': now,
      'updated_at': now,
    });
  }

  /// 通过原子事务把"同一天答对则不升级"逻辑放到服务端读取上。
  /// 之前依赖 localStorage 的同步比较，现在改为 Firestore 事务。
  Future<void> promoteWordMemoryLevel(String wordId) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final docRef = _wordsRef.doc(wordId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final lastCorrectAt = (data['last_correct_at'] as int?) ?? 0;
      final currentLevel = (data['memory_level'] as int?) ?? 1;

      final lastDay = DateTime.fromMillisecondsSinceEpoch(lastCorrectAt);
      final sameDay = lastCorrectAt > 0 &&
          lastDay.year == now.year &&
          lastDay.month == now.month &&
          lastDay.day == now.day;

      final newLevel = sameDay
          ? currentLevel
          : SpacedRepetitionService.nextLevel(currentLevel);

      tx.update(docRef, {
        'memory_level': newLevel,
        'last_correct_at': nowMs,
        'updated_at': nowMs,
      });
    });
  }

  Future<void> updateWord(Word word) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = word.toFirestoreMap();
    map['updated_at'] = now;
    await _wordsRef.doc(word.id).set(map);
  }

  Future<void> deleteWord(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _wordsRef.doc(id).update({'deleted': true, 'updated_at': now});
  }

  // ─── Tag operations ───────────────────────────────────────────────
  // 标签依附在单词上（单词的 tags 数组）。这里只需要在改名/删除时
  // 批量更新所有相关单词；自定义标签集合单独存在 SharedPreferences。

  String _customTagsKey(String bookId) => 'custom_tags_${_requireUid()}_$bookId';

  Future<List<String>> _getCustomTags(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_customTagsKey(bookId)) ?? <String>[];
  }

  Future<void> _setCustomTags(String bookId, List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customTagsKey(bookId), tags);
  }

  Future<void> insertTag(String bookId, String tag) async {
    final tags = await _getCustomTags(bookId);
    if (!tags.contains(tag)) {
      tags.add(tag);
      tags.sort();
      await _setCustomTags(bookId, tags);
    }
  }

  Future<List<String>> getAllTags(String bookId) async {
    final tags = <String>{};
    final snap = await _wordsRef
        .where('wordbook_id', isEqualTo: bookId)
        .where('deleted', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      final wordTags =
          (doc.data()['tags'] as List<dynamic>?)?.cast<String>() ?? const [];
      tags.addAll(wordTags);
    }
    tags.addAll(await _getCustomTags(bookId));
    return tags.toList()..sort();
  }

  Future<void> renameTag(String bookId, String oldTag, String newTag) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snap = await _wordsRef
        .where('wordbook_id', isEqualTo: bookId)
        .where('deleted', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      final tags =
          ((doc.data()['tags'] as List<dynamic>?) ?? const []).cast<String>().toList();
      final idx = tags.indexOf(oldTag);
      if (idx != -1) {
        tags[idx] = newTag;
        batch.update(doc.reference, {'tags': tags, 'updated_at': now});
      }
    }
    await batch.commit();

    // 同步自定义标签
    final custom = await _getCustomTags(bookId);
    final ci = custom.indexOf(oldTag);
    if (ci != -1) {
      custom[ci] = newTag;
      custom.sort();
      await _setCustomTags(bookId, custom);
    }
  }

  Future<void> deleteTag(String bookId, String tag) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snap = await _wordsRef
        .where('wordbook_id', isEqualTo: bookId)
        .where('deleted', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      final tags =
          ((doc.data()['tags'] as List<dynamic>?) ?? const []).cast<String>().toList();
      if (tags.remove(tag)) {
        batch.update(doc.reference, {'tags': tags, 'updated_at': now});
      }
    }
    await batch.commit();

    final custom = await _getCustomTags(bookId);
    if (custom.remove(tag)) {
      await _setCustomTags(bookId, custom);
    }
  }

  // ─── Scenario CRUD ────────────────────────────────────────────────

  Future<List<Scenario>> getAllScenarios() async {
    final snap = await _scenariosRef
        .where('deleted', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs
        .map((d) => Scenario.fromMap({'id': d.id, ...d.data()}))
        .toList();
  }

  Future<Scenario?> getScenario(String id) async {
    final doc = await _scenariosRef.doc(id).get();
    if (!doc.exists) return null;
    return Scenario.fromMap({'id': doc.id, ...doc.data()!});
  }

  Future<void> insertScenario(Scenario scenario) async {
    await _scenariosRef.doc(scenario.id).set(scenario.toFirestoreMap());
  }

  Future<void> updateScenario(Scenario scenario) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    scenario.updatedAt = now;
    await _scenariosRef.doc(scenario.id).set(scenario.toFirestoreMap());
  }

  Future<void> deleteScenario(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _scenariosRef.doc(id).update({'deleted': true, 'updated_at': now});
  }

  // ─── Settings（保留 SharedPreferences，本地优先；登录后镜像到云端）──

  Future<String?> getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(key);
    debugPrint('[Settings] getSetting $key = $val');
    return val;
  }

  Future<void> setSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    debugPrint('[Settings] setSetting $key = $value');
    if (_uid != null) {
      _settingsRef.set({key: value}, SetOptions(merge: true));
    }
  }
}
