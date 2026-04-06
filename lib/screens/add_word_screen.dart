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
  bool _isGenerating = false;

  String _notes = '';
  Key _notesFieldKey = UniqueKey();

  String _pronunciation = '';
  Key _pronunciationFieldKey = UniqueKey();

  List<String> _selectedTags = [];
  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await _dbService.getAllTags(widget.wordBook.id);
    setState(() => _availableTags = tags);
  }

  void _setNotes(String value) {
    setState(() {
      _notes = value;
      _notesFieldKey = UniqueKey();
    });
  }

  void _setPronunciation(String value) {
    setState(() {
      _pronunciation = value;
      _pronunciationFieldKey = UniqueKey();
    });
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

  Future<void> _generateTranslation() async {
    final word = _frontController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入单词')));
      return;
    }

    setState(() => _isGenerating = true);

    final mainLang = await _dbService.getSetting('main_language') ?? 'zh-CN';
    final sourceLang = widget.wordBook.language;

    final translationFuture = _translationService
        .translate(word, sourceLang, mainLang)
        .catchError((e) => null);
    final exampleFuture = _translationService
        .getExampleSentence(word, sourceLang)
        .catchError((e) => null);
    final pronunciationFuture = _translationService
        .getPronunciation(word, sourceLang)
        .catchError((e) => null);

    final translation = await translationFuture;
    if (mounted && translation != null) {
      _backController.value = TextEditingValue(text: translation);
    }

    final pronunciation = await pronunciationFuture;
    if (mounted && pronunciation != null) {
      _setPronunciation(pronunciation);
    }

    final example = await exampleFuture;
    if (!mounted) return;

    if (example != null) {
      final exampleTranslation = await _translationService
          .translate(example, sourceLang, mainLang)
          .catchError((e) => null);
      if (!mounted) return;

      final notesText = (exampleTranslation != null && exampleTranslation.isNotEmpty)
          ? '$example\n$exampleTranslation'
          : example;
      _setNotes(notesText);
    }

    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _saveWord() async {
    if (_frontController.text.isEmpty || _backController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写单词和译文')));
      return;
    }

    // 验重：检查同一单词本中是否已有相同正面
    final existing = await _dbService.getWordsByBookId(widget.wordBook.id);
    final duplicate = existing.any(
      (w) => w.front.trim().toLowerCase() == _frontController.text.trim().toLowerCase(),
    );
    if (duplicate && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('单词已存在'),
          content: Text('「${_frontController.text.trim()}」在本单词本中已存在，是否仍要添加？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('仍然添加')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final word = Word(
      id: const Uuid().v4(),
      wordBookId: widget.wordBook.id,
      front: _frontController.text,
      back: _backController.text,
      notes: _notes,
      tags: _selectedTags,
      pronunciation: _pronunciation,
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            TextFormField(
              key: _notesFieldKey,
              initialValue: _notes,
              onChanged: (v) => _notes = v,
              decoration: const InputDecoration(labelText: '注释/例句'),
              maxLines: null,
            ),
            TextFormField(
              key: _pronunciationFieldKey,
              initialValue: _pronunciation,
              onChanged: (v) => _pronunciation = v,
              decoration: const InputDecoration(labelText: '读音'),
            ),
            const SizedBox(height: 16),
            // 标签区域
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
