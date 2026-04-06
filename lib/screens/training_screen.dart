import 'package:flutter/material.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/spaced_repetition.dart';
import '../services/tts_service.dart';

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
  final _tts = TtsService();

  List<Word> _queue = [];
  int _currentIndex = 0;
  // 0=正面, 1=注释, 2=译文
  int _showStep = 0;

  // 滑动相关
  double _dragOffset = 0;
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;
  double _snapFrom = 0;
  double _snapTo = 0;

  // 本次训练中被右划过的单词ID集合（不能在本次升级）
  final Set<String> _swipedRightIds = {};

  bool _loaded = false;
  bool _voiceMode = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        setState(() {
          _dragOffset = _snapAnimation.value;
        });
      });
    _showTagSelector();
  }

  @override
  void dispose() {
    _snapController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _speak(String text) {
    if (text.isEmpty) return;
    _tts.speak(text, widget.wordBook.language);
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

    // 选择复习数量和模式
    final result = await showDialog<_TrainingConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CountSelectorDialog(defaultCount: defaultCount),
    );

    if (!mounted) return;
    if (result == null) {
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

    final selected = _srService.selectWordsForTraining(filteredWords, result.count);
    setState(() {
      _queue = selected;
      _voiceMode = result.voiceMode;
      _loaded = true;
    });

    // 自动播放第一张卡片
    if (_queue.isNotEmpty) {
      _speak(_queue[0].front);
    }
  }

  Word get _currentWord => _queue[_currentIndex];

  void _onTap() {
    if (_queue.isEmpty) return;
    setState(() {
      _showStep = (_showStep + 1) % 3;
    });
  }

  Future<void> _swipeLeft() async {
    final word = _currentWord;
    if (!_swipedRightIds.contains(word.id)) {
      await _dbService.promoteWordMemoryLevel(word.id);
    } else {
      await _dbService.updateWordMemoryLevel(
        word.id,
        1,
        updateCorrectTime: false,
      );
    }
    _nextCard(remove: true);
  }

  Future<void> _swipeRight() async {
    final word = _currentWord;
    _swipedRightIds.add(word.id);
    await _dbService.updateWordMemoryLevel(word.id, 1, updateCorrectTime: false);

    setState(() {
      final w = _queue.removeAt(_currentIndex);
      _queue.add(w.copyWith(memoryLevel: 1));
      _dragOffset = 0;
      _showStep = 0;
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
    });

    if (_queue.isNotEmpty) {
      _speak(_currentWord.front);
    }
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

    if (_queue.isNotEmpty) {
      _speak(_currentWord.front);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_snapController.isAnimating) return;
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.35;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset < -threshold || velocity < -800) {
      // 左划飞出
      _animateAndSwipe(to: -screenWidth * 1.5, onComplete: _swipeLeft);
    } else if (_dragOffset > threshold || velocity > 800) {
      // 右划飞出
      _animateAndSwipe(to: screenWidth * 1.5, onComplete: _swipeRight);
    } else {
      // 弹回
      _animateTo(0);
    }
  }

  void _animateAndSwipe({required double to, required Future<void> Function() onComplete}) {
    _snapFrom = _dragOffset;
    _snapTo = to;
    _snapAnimation = Tween<double>(begin: _snapFrom, end: _snapTo).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    );
    _snapController.forward(from: 0).then((_) async {
      await onComplete();
    });
  }

  void _animateTo(double target) {
    _snapFrom = _dragOffset;
    _snapTo = target;
    _snapAnimation = Tween<double>(begin: _snapFrom, end: _snapTo).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    );
    _snapController.forward(from: 0);
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
        actions: [
          IconButton(
            icon: Icon(_voiceMode ? Icons.visibility_off : Icons.visibility),
            tooltip: _voiceMode ? '显示单词' : '隐藏单词',
            onPressed: () => setState(() => _voiceMode = !_voiceMode),
          ),
        ],
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
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                  _showStep == 0
                      ? '点击查看注释'
                      : (_showStep == 1 ? '点击查看译文' : '左划记住 / 右划再来'),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 320,
            height: 240,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_voiceMode)
                  const Text(
                    '我是谁？',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey),
                  )
                else
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
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _speak(word.front),
          child: const Icon(Icons.volume_up, size: 48, color: Colors.blueAccent),
        ),
      ],
    );
  }
}

class _TrainingConfig {
  final int count;
  final bool voiceMode;
  _TrainingConfig({required this.count, required this.voiceMode});
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
      title: const Text('训练设置'),
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
              Navigator.pop(context, _TrainingConfig(count: count, voiceMode: false));
            }
          },
          child: const Text('开始'),
        ),
      ],
    );
  }
}


