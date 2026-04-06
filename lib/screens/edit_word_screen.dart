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

  List<String> _selectedTags = [];
  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.word.front);
    _backController = TextEditingController(text: widget.word.back);
    _notesController = TextEditingController(text: widget.word.notes);
    _selectedTags = List<String>.from(widget.word.tags);
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await _dbService.getAllTags(widget.word.wordBookId);
    setState(() => _availableTags = tags);
  }

  Future<void> _pickTag() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = controller.text.trim().toLowerCase();
            final filtered = _availableTags
                .where((t) => !_selectedTags.contains(t) && t.toLowerCase().contains(query))
                .toList();
            return AlertDialog(
              title: const Text('选择标签'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '搜索标签…',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('无匹配标签', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(filtered[i]),
                            dense: true,
                            onTap: () {
                              setState(() {
                                if (!_selectedTags.contains(filtered[i])) {
                                  _selectedTags.add(filtered[i]);
                                }
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
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
      tags: _selectedTags,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _frontController, decoration: const InputDecoration(labelText: '单词')),
            TextField(controller: _backController, decoration: const InputDecoration(labelText: '译文')),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: '注释/例句'),
              maxLines: null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickTag,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '标签'),
                child: _selectedTags.isEmpty
                    ? const Text('点击选择标签', style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _selectedTags.map((tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _selectedTags.remove(tag)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _saveWord, child: const Text('保存')),
            ),
          ],
        ),
      ),
    );
  }
}
