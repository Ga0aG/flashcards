import 'package:flutter/material.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/spaced_repetition.dart';

class TrainingScreen extends StatefulWidget {
  final WordBook wordBook;
  const TrainingScreen({super.key, required this.wordBook});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  final _dbService = DatabaseService();
  final _srService = SpacedRepetitionService();

  List<Word> _queue = [];
  int _currentIndex = 0;
  // 0=正面, 1=注释, 2=译文
  int _showStep = 0;

  // 滑动相关
  double _dragOffset = 0;
  bool _isDragging = false;

  // 本次训练中被右划过的单词ID集合（不能在本次升级）
  final Set<String> _swipedRightIds = {};

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _showTagSelector();
  }

  Future<void> _showTagSelector() async {
    final allWords = await _dbService.getWordsByBookId(widget.wordBook.id);

    if (allWords.isEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('没有单词'),
            content: const Text('请先添加单词后再进行记忆训练'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    // 收集所有标签
    final tagSet = <String>{};
    for (final w in allWords) {
      tagSet.addAll(w.tags);
    }
    final tags = tagSet.toList()..sort();

    if (!mounted) return;

    // 选择标签
    String? selectedTag = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TagSelectorDialog(tags: tags),
    );

    if (!mounted) return;
    if (selectedTag == null) {
      Navigator.pop(context);
      return;
    }

    // 读取默认复习数量
    final countStr = await _dbService.getSetting('default_review_count');
    final defaultCount = int.tryParse(countStr ?? '20') ?? 20;

    if (!mounted) return;

    // 选择复习数量
    final count = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CountSelectorDialog(defaultCount: defaultCount),
    );

    if (!mounted) return;
    if (count == null) {
      Navigator.pop(context);
      return;
    }

    // 根据标签过滤单词
    List<Word> filteredWords;
    if (selectedTag == '__all__') {
      filteredWords = allWords;
    } else {
      filteredWords = allWords.where((w) => w.tags.contains(selectedTag)).toList();
    }

    final selected = _srService.selectWordsForTraining(filteredWords, count);
    setState(() {
      _queue = selected;
      _loaded = true;
    });
  }

  Word get _currentWord => _queue[_currentIndex];

  void _onTap() {
    if (_queue.isEmpty) return;
    setState(() {
      if (_showStep < 2) {
        _showStep++;
      }
    });
  }

  Future<void> _swipeLeft() async {
    // 记住啦：升级记忆等级（如果本次训练没被右划过）
    final word = _currentWord;
    if (!_swipedRightIds.contains(word.id)) {
      await _dbService.promoteWordMemoryLevel(word.id);
    } else {
      // 被右划过，本次不升级，但更新正确时间
      await _dbService.updateWordMemoryLevel(
        word.id,
        1,
        updateCorrectTime: false,
      );
    }
    _nextCard(remove: true);
  }

  Future<void> _swipeRight() async {
    // 再来一次：记忆程度重置为1，放到队尾
    final word = _currentWord;
    _swipedRightIds.add(word.id);
    await _dbService.updateWordMemoryLevel(word.id, 1, updateCorrectTime: false);

    setState(() {
      // 从当前位置移除，添加到队尾
      final w = _queue.removeAt(_currentIndex);
      _queue.add(w.copyWith(memoryLevel: 1));
      _dragOffset = 0;
      _showStep = 0;
      // currentIndex不变（下一张已经是原来的下一张了）
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
    });
  }

  void _nextCard({required bool remove}) {
    setState(() {
      if (remove) {
        _queue.removeAt(_currentIndex);
      }
      _dragOffset = 0;
      _showStep = 0;
      if (_queue.isEmpty) {
        // 训练完成
      } else if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _isDragging = true;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final threshold = MediaQuery.of(context).size.width * 0.35;
    if (_dragOffset < -threshold) {
      // 左划 -> 记住啦
      _swipeLeft();
    } else if (_dragOffset > threshold) {
      // 右划 -> 再来一次
      _swipeRight();
    } else {
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('记忆强化')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('记忆强化')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.celebration, size: 80, color: Colors.green),
              SizedBox(height: 16),
              Text('本次训练完成！', style: TextStyle(fontSize: 24)),
            ],
          ),
        ),
      );
    }

    final word = _currentWord;
    final screenWidth = MediaQuery.of(context).size.width;
    final swipeRatio = (_dragOffset / screenWidth).clamp(-1.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1}/${_queue.length}'),
      ),
      body: GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onTap: _onTap,
        child: Stack(
          children: [
            Center(
              child: Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: Transform.rotate(
                  angle: swipeRatio * 0.15,
                  child: _buildCard(word),
                ),
              ),
            ),
            // 左划提示
            if (_dragOffset < -30)
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(
                        ((-_dragOffset - 30) / (screenWidth * 0.3)).clamp(0.0, 1.0),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '记住啦 ✓',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // 右划提示
            if (_dragOffset > 30)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(
                        ((_dragOffset - 30) / (screenWidth * 0.3)).clamp(0.0, 1.0),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '再来一次 ↩',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // 底部提示
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _showStep == 0 ? '点击查看注释' : (_showStep == 1 ? '点击查看译文' : '左划记住 / 右划再来'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Word word) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 320,
        height: 240,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              word.front,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_showStep >= 1 && word.notes.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                word.notes,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            if (_showStep >= 2) ...[
              const SizedBox(height: 8),
              Text(
                word.back,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagSelectorDialog extends StatefulWidget {
  final List<String> tags;
  const _TagSelectorDialog({required this.tags});

  @override
  State<_TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<_TagSelectorDialog> {
  String _selected = '__all__';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择标签'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            RadioListTile<String>(
              title: const Text('全部'),
              value: '__all__',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            ...widget.tags.map(
              (tag) => RadioListTile<String>(
                title: Text(tag),
                value: tag,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v!),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _CountSelectorDialog extends StatefulWidget {
  final int defaultCount;
  const _CountSelectorDialog({required this.defaultCount});

  @override
  State<_CountSelectorDialog> createState() => _CountSelectorDialogState();
}

class _CountSelectorDialogState extends State<_CountSelectorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultCount.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('复习数量'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '单词数量',
          hintText: '输入要复习的单词数量',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
          onPressed: () {
            final count = int.tryParse(_controller.text);
            if (count != null && count > 0) {
              Navigator.pop(context, count);
            }
          },
          child: const Text('开始'),
        ),
      ],
    );
  }
}
