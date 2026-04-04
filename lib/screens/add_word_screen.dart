import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/wordbook.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';

class AddWordScreen extends StatefulWidget {
  final WordBook wordBook;
  const AddWordScreen({super.key, required this.wordBook});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _dbService = DatabaseService();
  final _translationService = TranslationService();
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isGenerating = false;

  Future<void> _generateTranslation() async {
    final word = _frontController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入单词')));
      return;
    }

    setState(() => _isGenerating = true);

    final mainLang = await _dbService.getSetting('main_language') ?? 'zh-CN';
    final sourceLang = widget.wordBook.language;

    final results = await Future.wait([
      _translationService.translate(word, sourceLang, mainLang),
      _translationService.getExampleSentence(word, sourceLang),
    ]);

    final translation = results[0];
    final example = results[1];

    // Translate the example sentence into the user's main language
    String? exampleTranslation;
    if (example != null) {
      exampleTranslation = await _translationService.translate(example, sourceLang, mainLang);
    }

    print('[Generate] translation: $translation');
    print('[Generate] example: $example');

    if (translation != null) _backController.text = translation;
    if (example != null) {
      _notesController.text = exampleTranslation != null
          ? '$example\n$exampleTranslation'
          : example;
    }

    setState(() => _isGenerating = false);

    if (translation == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('自动翻译失败，请手动输入')));
    }
  }

  Future<void> _saveWord() async {
    if (_frontController.text.isEmpty || _backController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写单词和译文')));
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final word = Word(
      id: const Uuid().v4(),
      wordBookId: widget.wordBook.id,
      front: _frontController.text,
      back: _backController.text,
      notes: _notesController.text,
      tags: _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      pronunciation: '',
      memoryLevel: 1,
      lastCorrectAt: 0,
      createdAt: now,
    );

    await _dbService.insertWord(word);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加单词')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _frontController,
                      decoration: const InputDecoration(labelText: '单词（正面）'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateTranslation,
                    icon: _isGenerating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: const Text('生成'),
                  ),
                ],
              ),
              TextField(controller: _backController, decoration: const InputDecoration(labelText: '译文（背面）')),
              TextField(controller: _notesController, decoration: const InputDecoration(labelText: '注释/例句')),
              TextField(controller: _tagsController, decoration: const InputDecoration(labelText: '标签(逗号分隔)')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveWord, child: const Text('保存')),
            ],
          ),
      ),
    );
  }
}
