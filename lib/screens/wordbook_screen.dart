import 'package:flutter/material.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';
import 'add_word_screen.dart';
import 'edit_word_screen.dart';
import 'training_screen.dart';
import 'tag_management_screen.dart';
import 'home_screen.dart' show langFlag, langName;

// memoryLevel 值: 1,2,4,7,15,30 → 索引 0-5
int _memoryLevelIndex(int level) {
  const levels = [1, 2, 4, 7, 15, 30];
  final idx = levels.indexOf(level);
  return idx == -1 ? 0 : idx;
}

Widget _memoryClover(int memoryLevel) {
  final lit = _memoryLevelIndex(memoryLevel); // 0=全灰, 1=亮1片, ...5=全亮
  const litColor = Color(0xFF4CAF50);
  const dimColor = Color(0xFFBDBDBD);

  // 5片叶子，顺时针排列（上、右上、右下、左下、左上）
  const positions = [
    Offset(10, 0),   // 上
    Offset(20, 8),   // 右上
    Offset(16, 20),  // 右下
    Offset(4, 20),   // 左下
    Offset(0, 8),    // 左上
  ];

  return SizedBox(
    width: 28,
    height: 28,
    child: CustomPaint(
      painter: _CloverPainter(litCount: lit, litColor: litColor, dimColor: dimColor, positions: positions),
    ),
  );
}

class _CloverPainter extends CustomPainter {
  final int litCount;
  final Color litColor;
  final Color dimColor;
  final List<Offset> positions;

  _CloverPainter({required this.litCount, required this.litColor, required this.dimColor, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 28;
    for (int i = 0; i < 5; i++) {
      final paint = Paint()..color = i < litCount ? litColor : dimColor;
      final center = Offset(positions[i].dx * scale + 4 * scale, positions[i].dy * scale + 4 * scale);
      canvas.drawCircle(center, 4 * scale, paint);
    }
    // 茎
    final stemPaint = Paint()..color = dimColor..strokeWidth = 1.5 * scale..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(14 * scale, 20 * scale), Offset(14 * scale, 26 * scale), stemPaint);
  }

  @override
  bool shouldRepaint(_CloverPainter old) => old.litCount != litCount;
}

class WordBookScreen extends StatefulWidget {
  final WordBook wordBook;
  const WordBookScreen({super.key, required this.wordBook});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  final _dbService = DatabaseService();
  final _tts = TtsService();
  List<Word> _words = [];
  List<String> _allTags = [];
  String? _selectedTag; // null = 不过滤

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final words = await _dbService.getWordsByBookId(widget.wordBook.id);
    final tags = await _dbService.getAllTags(widget.wordBook.id);
    setState(() {
      _words = words;
      _allTags = tags;
      // 如果当前筛选标签已不存在，则重置
      if (_selectedTag != null && !tags.contains(_selectedTag)) {
        _selectedTag = null;
      }
    });
  }

  List<Word> get _filteredWords {
    if (_selectedTag == null) return _words;
    return _words.where((w) => w.tags.contains(_selectedTag)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayWords = _filteredWords;
    return Scaffold(
      appBar: AppBar(
        title: Text('${langFlag(widget.wordBook.language)} ${langName(widget.wordBook.language)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: '记忆强化',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrainingScreen(wordBook: widget.wordBook),
                ),
              );
              _loadWords();
            },
          ),
          IconButton(
            icon: const Icon(Icons.label),
            tooltip: '标签管理',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TagManagementScreen(wordBook: widget.wordBook),
                ),
              );
              _loadWords();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加单词',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddWordScreen(wordBook: widget.wordBook),
                ),
              );
              _loadWords();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('筛选标签：'),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _selectedTag,
                  hint: const Text('无'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('无'),
                    ),
                    ..._allTags.map((tag) => DropdownMenuItem<String?>(
                          value: tag,
                          child: Text(tag),
                        )),
                  ],
                  onChanged: (value) => setState(() => _selectedTag = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: displayWords.isEmpty
                ? Center(
                    child: Text(_words.isEmpty ? '还没有单词，点击右上角 + 添加' : '该标签下没有单词'),
                  )
                : ListView.separated(
                    itemCount: displayWords.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final word = displayWords[index];
                      return ListTile(
                        title: Text(word.front),
                        subtitle: Text(word.back),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _memoryClover(word.memoryLevel),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              onPressed: () => _tts.speak(word.front, widget.wordBook.language),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditWordScreen(word: word),
                                  ),
                                );
                                _loadWords();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('确认删除'),
                                    content: Text('确定要删除"${word.front}"吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _dbService.deleteWord(word.id);
                                  _loadWords();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
