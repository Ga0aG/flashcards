import 'package:flutter/material.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import 'add_word_screen.dart';
import 'edit_word_screen.dart';
import 'training_screen.dart';

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
        title: Text(widget.wordBook.name),
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

