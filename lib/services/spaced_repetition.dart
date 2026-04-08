import 'dart:math';
import '../models/word.dart';

class SpacedRepetitionService {
  static const List<int> memoryLevels = [1, 2, 4, 7, 15, 30];

  /// 获取下一个记忆等级，若已是最高级则保持
  static int nextLevel(int currentLevel) {
    final idx = memoryLevels.indexOf(currentLevel);
    if (idx == -1 || idx >= memoryLevels.length - 1) return memoryLevels.last;
    return memoryLevels[idx + 1];
  }

  /// 判断单词是否到期需要复习（艾宾浩斯遗忘曲线）
  /// - memoryLevel=1：始终到期（新词/重置词）
  /// - lastCorrectAt=0（从未答对）：始终到期
  /// - 其他：距上次答对超过 memoryLevel 天则到期
  static bool isDue(Word word, DateTime now) {
    if (word.memoryLevel == 1) return true;
    if (word.lastCorrectAt == 0) return true;
    final lastCorrect = DateTime.fromMillisecondsSinceEpoch(word.lastCorrectAt);
    final daysSince = now.difference(lastCorrect).inDays;
    return daysSince >= word.memoryLevel;
  }

  /// 判断单词今天是否已答对（当天通过，排除出训练）
  static bool _passedToday(Word word, DateTime today) {
    if (word.lastCorrectAt == 0) return false;
    final lastCorrect = DateTime.fromMillisecondsSinceEpoch(word.lastCorrectAt);
    return lastCorrect.year == today.year &&
        lastCorrect.month == today.month &&
        lastCorrect.day == today.day;
  }

  /// 距离到期还剩多少毫秒（用于补充排序，越小越优先）
  static int _msUntilDue(Word word, DateTime now) {
    if (isDue(word, now)) return 0;
    final lastCorrect = DateTime.fromMillisecondsSinceEpoch(word.lastCorrectAt);
    final dueAt = lastCorrect.add(Duration(days: word.memoryLevel));
    final remaining = dueAt.difference(now).inMilliseconds;
    return remaining < 0 ? 0 : remaining;
  }

  List<Word> selectWordsForTraining(List<Word> allWords, int count) {
    if (allWords.isEmpty || count <= 0) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. 排除当天已通过的单词
    final candidates = allWords.where((w) => !_passedToday(w, today)).toList();

    // 2. 分离到期 / 未到期
    final due = candidates.where((w) => isDue(w, now)).toList();
    final notDue = candidates.where((w) => !isDue(w, now)).toList();

    // 3. 到期单词按 createdAt 升序（旧词优先）
    due.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // 4. 取前 count 个到期单词
    final selected = due.take(count).toList();

    // 5. 不足时从未到期单词补充，按"最快到期"排序
    if (selected.length < count) {
      notDue.sort((a, b) => _msUntilDue(a, now).compareTo(_msUntilDue(b, now)));
      final needed = count - selected.length;
      selected.addAll(notDue.take(needed));
    }

    // 6. 打乱顺序，避免每次出现顺序固定
    selected.shuffle(Random());
    return selected;
  }
}
