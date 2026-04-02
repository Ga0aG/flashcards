import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/database_service.dart';

class EditWordScreen extends StatefulWidget {
  final Word word;
  const EditWordScreen({super.key, required this.word});

  @override
  State<EditWordScreen> createState() => _EditWordScreenState();
}

class _EditWordScreenState extends State<EditWordScreen> {
  final _dbService = DatabaseService();
  late TextEditingController _frontController;
  late TextEditingController _backController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.word.front);
    _backController = TextEditingController(text: widget.word.back);
    _notesController = TextEditingController(text: widget.word.notes);
    _tagsController = TextEditingController(text: widget.word.tags.join(','));
  }

  Future<void> _saveWord() async {
    if (_frontController.text.isEmpty || _backController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写单词和译文')));
      return;
    }

    final updatedWord = Word(
      id: widget.word.id,
      wordBookId: widget.word.wordBookId,
      front: _frontController.text,
      back: _backController.text,
      notes: _notesController.text,
      tags: _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      pronunciation: widget.word.pronunciation,
      memoryLevel: widget.word.memoryLevel,
      lastCorrectAt: widget.word.lastCorrectAt,
      createdAt: widget.word.createdAt,
    );

    await _dbService.updateWord(updatedWord);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑单词')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _frontController, decoration: const InputDecoration(labelText: '单词')),
            TextField(controller: _backController, decoration: const InputDecoration(labelText: '译文')),
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
