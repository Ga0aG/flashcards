import 'package:flutter/material.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import 'add_word_screen.dart';
import 'edit_word_screen.dart';
import 'training_screen.dart';
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
  List<Word> _words = [];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final words = await _dbService.getWordsByBookId(widget.wordBook.id);
    setState(() => _words = words);
  }

  @override
  Widget build(BuildContext context) {
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
      body: _words.isEmpty
          ? const Center(child: Text('还没有单词，点击右上角 + 添加'))
          : ListView.builder(
              itemCount: _words.length,
              itemBuilder: (context, index) {
                final word = _words[index];
                return ListTile(
                  title: Text(word.front),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.back),
                      if (word.tags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: word.tags
                              .map(
                                (tag) => Chip(
                                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  isThreeLine: word.tags.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _memoryClover(word.memoryLevel),
                      const SizedBox(width: 4),
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
    );
  }
}

