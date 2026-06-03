import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/wordbook.dart';
import '../models/scenario.dart';
import 'database_service.dart';

class SyncService {
  final _db = DatabaseService();
  final _firestore = FirebaseFirestore.instance;

  CollectionReference _wordbooksRef(String uid) =>
      _firestore.collection('users/$uid/wordbooks');
  CollectionReference _wordsRef(String uid) =>
      _firestore.collection('users/$uid/words');
  CollectionReference _scenariosRef(String uid) =>
      _firestore.collection('users/$uid/scenarios');

  Future<void> migrateIfNeeded(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'migrated_$uid';
    if (prefs.getBool(key) == true) return;

    // 读取本地数据
    final localBooks = await _db.getAllWordBooks();
    final localWords = <Word>[];
    for (final book in localBooks) {
      localWords.addAll(await _db.getWordsByBookId(book.id));
    }
    final localScenarios = await _db.getAllScenarios();

    if (localBooks.isEmpty && localWords.isEmpty && localScenarios.isEmpty) {
      await prefs.setBool(key, true);
      return;
    }

    // 检查云端是否已有数据
    final cloudBooksSnap = await _wordbooksRef(uid).limit(1).get();
    final cloudScenariosSnap = await _scenariosRef(uid).limit(1).get();
    final cloudHasData =
        cloudBooksSnap.docs.isNotEmpty || cloudScenariosSnap.docs.isNotEmpty;

    if (cloudHasData) {
      // 云端已有数据（换设备登录），合并
      await _mergeToCloud(uid, localBooks, localWords, localScenarios);
    } else {
      // 首次登录，直接上传
      await _uploadAll(uid, localBooks, localWords, localScenarios);
    }

    await prefs.setBool(key, true);
  }

  Future<void> _uploadAll(String uid, List<WordBook> books, List<Word> words,
      List<Scenario> scenarios) async {
    const batchSize = 400;
    var batch = _firestore.batch();
    int count = 0;

    for (final book in books) {
      batch.set(_wordbooksRef(uid).doc(book.id), _bookToFirestore(book));
      count++;
      if (count >= batchSize) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    for (final word in words) {
      batch.set(_wordsRef(uid).doc(word.id), _wordToFirestore(word));
      count++;
      if (count >= batchSize) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    for (final s in scenarios) {
      batch.set(_scenariosRef(uid).doc(s.id), s.toFirestoreMap());
      count++;
      if (count >= batchSize) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }

  Future<void> _mergeToCloud(String uid, List<WordBook> localBooks,
      List<Word> localWords, List<Scenario> localScenarios) async {
    // 获取云端所有 ID 和 updatedAt
    final cloudBooksSnap = await _wordbooksRef(uid).get();
    final cloudBookMap = {for (final d in cloudBooksSnap.docs) d.id: d.data() as Map<String, dynamic>};

    final cloudWordsSnap = await _wordsRef(uid).get();
    final cloudWordMap = {for (final d in cloudWordsSnap.docs) d.id: d.data() as Map<String, dynamic>};

    final cloudScenariosSnap = await _scenariosRef(uid).get();
    final cloudScenarioMap = {
      for (final d in cloudScenariosSnap.docs) d.id: d.data() as Map<String, dynamic>
    };

    var batch = _firestore.batch();
    int count = 0;

    Future<void> commitIfNeeded() async {
      if (count >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    for (final book in localBooks) {
      final cloud = cloudBookMap[book.id];
      if (cloud == null || (cloud['updated_at'] as int? ?? 0) < book.updatedAt) {
        batch.set(_wordbooksRef(uid).doc(book.id), _bookToFirestore(book));
        count++;
        await commitIfNeeded();
      }
    }
    for (final word in localWords) {
      final cloud = cloudWordMap[word.id];
      final localUpdatedAt = word.lastCorrectAt > 0 ? word.lastCorrectAt : word.createdAt;
      if (cloud == null || (cloud['updated_at'] as int? ?? 0) < localUpdatedAt) {
        batch.set(_wordsRef(uid).doc(word.id), _wordToFirestore(word));
        count++;
        await commitIfNeeded();
      }
    }
    for (final s in localScenarios) {
      final cloud = cloudScenarioMap[s.id];
      if (cloud == null || (cloud['updated_at'] as int? ?? 0) < s.updatedAt) {
        batch.set(_scenariosRef(uid).doc(s.id), s.toFirestoreMap());
        count++;
        await commitIfNeeded();
      }
    }
    if (count > 0) await batch.commit();
  }

  Future<void> pullLatest(String uid) async {
    // 拉取云端数据，合并到本地
    final booksSnap = await _wordbooksRef(uid)
        .where('deleted', isEqualTo: false)
        .get();
    final wordsSnap = await _wordsRef(uid)
        .where('deleted', isEqualTo: false)
        .get();

    final localBooks = await _db.getAllWordBooks();
    final localBookMap = {for (final b in localBooks) b.id: b};

    for (final doc in booksSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cloudBook = WordBook.fromMap({
        'id': doc.id,
        'language': data['language'],
        'created_at': data['created_at'],
        'updated_at': data['updated_at'],
      });
      final local = localBookMap[doc.id];
      if (local == null || local.updatedAt < cloudBook.updatedAt) {
        await _db.upsertWordBook(cloudBook);
      }
    }

    // 删除本地有但云端已软删除的 wordbook
    final cloudBookIds = booksSnap.docs.map((d) => d.id).toSet();
    for (final local in localBooks) {
      if (!cloudBookIds.contains(local.id)) {
        await _db.deleteWordBookLocal(local.id);
      }
    }

    // 处理 words
    final allLocalWords = <Word>[];
    final updatedBooks = await _db.getAllWordBooks();
    for (final b in updatedBooks) {
      allLocalWords.addAll(await _db.getWordsByBookId(b.id));
    }
    final localWordMap = {for (final w in allLocalWords) w.id: w};

    for (final doc in wordsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      final cloudWord = Word(
        id: doc.id,
        wordBookId: data['wordbook_id'] ?? '',
        front: data['front'] ?? '',
        back: data['back'] ?? '',
        notes: data['notes'] ?? '',
        tags: tags,
        pronunciation: data['pronunciation'] ?? '',
        memoryLevel: data['memory_level'] ?? 1,
        lastCorrectAt: data['last_correct_at'] ?? 0,
        createdAt: data['created_at'] ?? 0,
      );
      final local = localWordMap[doc.id];
      final cloudUpdatedAt = data['updated_at'] as int? ?? 0;
      final localUpdatedAt = local?.lastCorrectAt ?? 0;
      if (local == null || localUpdatedAt < cloudUpdatedAt) {
        await _db.upsertWord(cloudWord);
      }
    }

    // 删除本地有但云端已软删除的 word
    final cloudWordIds = wordsSnap.docs.map((d) => d.id).toSet();
    for (final local in allLocalWords) {
      if (!cloudWordIds.contains(local.id)) {
        await _db.deleteWordLocal(local.id);
      }
    }

    // 拉取场景
    final scenariosSnap = await _scenariosRef(uid)
        .where('deleted', isEqualTo: false)
        .get();
    final localScenarios = await _db.getAllScenarios();
    final localScenarioMap = {for (final s in localScenarios) s.id: s};
    for (final doc in scenariosSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cloud = Scenario.fromMap({
        'id': doc.id,
        'name': data['name'] ?? '',
        'created_at': data['created_at'] ?? 0,
        'updated_at': data['updated_at'] ?? 0,
        'sentences': data['sentences'] ?? const [],
      });
      final local = localScenarioMap[doc.id];
      if (local == null || local.updatedAt < cloud.updatedAt) {
        await _db.upsertScenario(cloud);
      }
    }
    final cloudScenarioIds = scenariosSnap.docs.map((d) => d.id).toSet();
    for (final local in localScenarios) {
      if (!cloudScenarioIds.contains(local.id)) {
        await _db.deleteScenarioLocal(local.id);
      }
    }
  }

  Map<String, dynamic> _bookToFirestore(WordBook book) => {
    'id': book.id,
    'language': book.language,
    'created_at': book.createdAt,
    'updated_at': book.updatedAt,
    'deleted': false,
  };

  Map<String, dynamic> _wordToFirestore(Word word) => {
    'id': word.id,
    'wordbook_id': word.wordBookId,
    'front': word.front,
    'back': word.back,
    'notes': word.notes,
    'tags': word.tags,
    'pronunciation': word.pronunciation,
    'memory_level': word.memoryLevel,
    'last_correct_at': word.lastCorrectAt,
    'created_at': word.createdAt,
    'updated_at': word.lastCorrectAt > 0 ? word.lastCorrectAt : word.createdAt,
    'deleted': false,
  };
}
