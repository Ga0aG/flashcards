import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/wordbook.dart';
import 'database_service.dart';

class SyncService {
  final _db = DatabaseService();
  final _firestore = FirebaseFirestore.instance;

  CollectionReference _wordbooksRef(String uid) =>
      _firestore.collection('users/$uid/wordbooks');
  CollectionReference _wordsRef(String uid) =>
      _firestore.collection('users/$uid/words');

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

    if (localBooks.isEmpty && localWords.isEmpty) {
      await prefs.setBool(key, true);
      return;
    }

    // 检查云端是否已有数据
    final cloudBooksSnap = await _wordbooksRef(uid).limit(1).get();
    final cloudHasData = cloudBooksSnap.docs.isNotEmpty;

    if (cloudHasData) {
      // 云端已有数据（换设备登录），合并
      await _mergeToCloud(uid, localBooks, localWords);
    } else {
      // 首次登录，直接上传
      await _uploadAll(uid, localBooks, localWords);
    }

    await prefs.setBool(key, true);
  }

  Future<void> _uploadAll(String uid, List<WordBook> books, List<Word> words) async {
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
    if (count > 0) await batch.commit();
  }

  Future<void> _mergeToCloud(String uid, List<WordBook> localBooks, List<Word> localWords) async {
    // 获取云端所有 ID 和 updatedAt
    final cloudBooksSnap = await _wordbooksRef(uid).get();
    final cloudBookMap = {for (final d in cloudBooksSnap.docs) d.id: d.data() as Map<String, dynamic>};

    final cloudWordsSnap = await _wordsRef(uid).get();
    final cloudWordMap = {for (final d in cloudWordsSnap.docs) d.id: d.data() as Map<String, dynamic>};

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
      if (cloud == null || (cloud['updated_at'] as int? ?? 0) < word.createdAt) {
        batch.set(_wordsRef(uid).doc(word.id), _wordToFirestore(word));
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
      final localUpdatedAt = local?.createdAt ?? 0;
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
    'updated_at': word.createdAt,
    'deleted': false,
  };
}
