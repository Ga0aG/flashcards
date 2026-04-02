import 'dart:math';
import '../models/word.dart';

class SpacedRepetitionService {
  // 记忆等级序列：1,2,4,7,15,30
  static const List<int> memoryLevels = [1, 2, 4, 7, 15, 30];

  // 每个等级对应的权重，等级越低权重越高
  static const Map<int, int> memoryWeights = {
    1: 1000, // 新单词/等级1必定出现（权重极高）
    2: 100,
    4: 70,
    7: 40,
    15: 20,
    30: 5,
  };

  /// 获取下一个记忆等级，若已是最高级则保持
  static int nextLevel(int currentLevel) {
    final idx = memoryLevels.indexOf(currentLevel);
    if (idx == -1 || idx >= memoryLevels.length - 1) return memoryLevels.last;
    return memoryLevels[idx + 1];
  }

  List<Word> selectWordsForTraining(List<Word> allWords, int count) {
    // 等级1（新词/被重置的词）按创建时间从旧到新全部优先出现
    final newWords = allWords.where((w) => w.memoryLevel == 1).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final oldWords = allWords.where((w) => w.memoryLevel != 1).toList();
    final needOld = (count - newWords.length).clamp(0, oldWords.length);
    final selectedOld = _weightedRandomSelection(oldWords, needOld);

    return [...newWords, ...selectedOld].take(count).toList();
  }

  List<Word> _weightedRandomSelection(List<Word> words, int count) {
    if (words.isEmpty || count <= 0) return [];

    final random = Random();
    final selected = <Word>[];
    final remaining = List<Word>.from(words);

    for (var i = 0; i < count && remaining.isNotEmpty; i++) {
      final totalWeight = remaining.fold<int>(
        0,
        (sum, w) => sum + (memoryWeights[w.memoryLevel] ?? 1),
      );
      var randomWeight = random.nextInt(totalWeight);

      for (var word in remaining) {
        randomWeight -= memoryWeights[word.memoryLevel] ?? 1;
        if (randomWeight < 0) {
          selected.add(word);
          remaining.remove(word);
          break;
        }
      }
    }

    return selected;
  }
}
