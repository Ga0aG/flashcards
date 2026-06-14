import 'package:flutter/material.dart';
import '../models/scenario.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';
import '../utils/languages.dart';

class ScenarioChatScreen extends StatefulWidget {
  final String scenarioId;
  final String targetLang;

  const ScenarioChatScreen({
    super.key,
    required this.scenarioId,
    required this.targetLang,
  });

  @override
  State<ScenarioChatScreen> createState() => _ScenarioChatScreenState();
}

class _ScenarioChatScreenState extends State<ScenarioChatScreen> {
  final _db = DatabaseService();
  final _translation = TranslationService();
  Scenario? _scenario;
  // 正在翻译的句子下标，用于显示 loading
  final Set<int> _translatingIndices = {};
  // 当前展开操作行的句子下标；-1 表示没有
  int _expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _db.getScenario(widget.scenarioId);
    if (!mounted || s == null) return;
    setState(() => _scenario = s);
    _backfillTranslations();
  }

  Future<void> _backfillTranslations() async {
    final s = _scenario;
    if (s == null) return;
    for (int i = 0; i < s.sentences.length; i++) {
      final sentence = s.sentences[i];
      final existing = sentence.translations[widget.targetLang];
      if (existing != null && existing.isNotEmpty) continue;
      if (sentence.sourceText.trim().isEmpty) continue;
      await _translateAt(i);
    }
  }

  Future<void> _translateAt(int index) async {
    final s = _scenario;
    if (s == null || index < 0 || index >= s.sentences.length) return;
    setState(() => _translatingIndices.add(index));
    try {
      var result = await _translation.translateSentence(
        s.sentences[index].sourceText,
        'zh',
        widget.targetLang,
      );
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        // 仅日语：在翻译结果上叠加 furigana
        if (widget.targetLang == 'ja') {
          result = await _translation.addFuriganaJa(result);
          if (!mounted) return;
        }
        s.sentences[index].translations[widget.targetLang] = result;
        await _db.updateScenario(s);
      }
    } finally {
      if (mounted) {
        setState(() => _translatingIndices.remove(index));
      }
    }
  }

  Future<String?> _promptInput({String? initial, required String title}) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: '请输入中文'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSentence(String side, {int? insertAt}) async {
    final text = await _promptInput(title: side == 'left' ? '左侧添加一句' : '右侧添加一句');
    if (text == null || text.isEmpty) return;
    final s = _scenario;
    if (s == null) return;
    final newSentence = ScenarioSentence(side: side, sourceText: text);
    final idx = insertAt ?? s.sentences.length;
    s.sentences.insert(idx, newSentence);
    await _db.updateScenario(s);
    if (!mounted) return;
    setState(() {});
    await _translateAt(idx);
  }

  Future<void> _editSentence(int index) async {
    final s = _scenario;
    if (s == null) return;
    final sentence = s.sentences[index];
    final sourceController = TextEditingController(text: sentence.sourceText);
    final translationController = TextEditingController(
      text: sentence.translations[widget.targetLang] ?? '',
    );
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑句子'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('中文'),
              TextField(controller: sourceController, maxLines: null),
              const SizedBox(height: 12),
              Text(langName(widget.targetLang)),
              TextField(controller: translationController, maxLines: null),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('保存')),
        ],
      ),
    );
    if (action != 'save') return;
    sentence.sourceText = sourceController.text.trim();
    sentence.translations[widget.targetLang] = translationController.text.trim();
    await _db.updateScenario(s);
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(int index) async {
    final s = _scenario;
    if (s == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这句话？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;
    s.sentences.removeAt(index);
    await _db.updateScenario(s);
    if (mounted) {
      setState(() {
        if (_expandedIndex == index) _expandedIndex = -1;
      });
    }
  }

  Future<void> _moveSentence(int index, int delta) async {
    final s = _scenario;
    if (s == null) return;
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= s.sentences.length) return;
    final sentence = s.sentences.removeAt(index);
    s.sentences.insert(newIndex, sentence);
    await _db.updateScenario(s);
    if (mounted) {
      setState(() {
        _expandedIndex = newIndex;
      });
    }
  }

  Future<void> _swapSide(int index) async {
    final s = _scenario;
    if (s == null || index < 0 || index >= s.sentences.length) return;
    final sentence = s.sentences[index];
    sentence.side = sentence.side == 'left' ? 'right' : 'left';
    await _db.updateScenario(s);
    if (mounted) setState(() {});
  }

  Widget _buildBubble(int index, ScenarioSentence sentence) {
    final isLeft = sentence.side == 'left';
    final translation = sentence.translations[widget.targetLang];
    final isLoading = _translatingIndices.contains(index);
    final isExpanded = _expandedIndex == index;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLeft ? const Color(0xFFE0E0E0) : const Color(0xFFB3E5FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sentence.sourceText, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          if (isLoading)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 6),
                Text('翻译中...', style: TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            )
          else if (translation != null && translation.isNotEmpty)
            Text(translation, style: const TextStyle(fontSize: 14, color: Colors.black87))
          else
            GestureDetector(
              onTap: () => _translateAt(index),
              child: const Text(
                '翻译失败，点击重试',
                style: TextStyle(fontSize: 13, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );

    final bubbleRow = GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? -1 : index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [bubble],
        ),
      ),
    );

    if (!isExpanded) return bubbleRow;

    final actionBar = Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 4),
      child: Row(
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: '在上方添加左侧句子',
            icon: const Icon(Icons.add_circle_outline),
            color: Colors.grey.shade700,
            onPressed: () => _addSentence('left', insertAt: index),
          ),
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () => _editSentence(index),
          ),
          IconButton(
            tooltip: '上移',
            icon: const Icon(Icons.arrow_upward),
            color: Colors.grey.shade700,
            onPressed: index > 0 ? () => _moveSentence(index, -1) : null,
          ),
          IconButton(
            tooltip: '下移',
            icon: const Icon(Icons.arrow_downward),
            color: Colors.grey.shade700,
            onPressed: index < (_scenario?.sentences.length ?? 0) - 1
                ? () => _moveSentence(index, 1)
                : null,
          ),
          IconButton(
            tooltip: '互换左右',
            icon: const Icon(Icons.swap_horiz),
            color: Colors.grey.shade700,
            onPressed: () => _swapSide(index),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: () => _confirmDelete(index),
          ),
          IconButton(
            tooltip: '在上方添加右侧句子',
            icon: const Icon(Icons.add_circle_outline),
            color: Colors.lightBlue.shade700,
            onPressed: () => _addSentence('right', insertAt: index),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bubbleRow, actionBar],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _scenario;
    return Scaffold(
      appBar: AppBar(
        title: Text(s?.name ?? '场景'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${langFlag(widget.targetLang)} ${langName(widget.targetLang)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: s.sentences.length,
              itemBuilder: (ctx, i) => _buildBubble(i, s.sentences[i]),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                heroTag: 'add-left',
                onPressed: () => _addSentence('left'),
                child: const Icon(Icons.add),
              ),
              FloatingActionButton(
                heroTag: 'add-right',
                onPressed: () => _addSentence('right'),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
