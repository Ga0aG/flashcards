import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/scenario.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../utils/languages.dart';
import 'scenario_chat_screen.dart';

const _scenarioLangKey = 'scenario_target_language';

class ScenarioListScreen extends StatefulWidget {
  const ScenarioListScreen({super.key});

  @override
  State<ScenarioListScreen> createState() => _ScenarioListScreenState();
}

class _ScenarioListScreenState extends State<ScenarioListScreen> {
  final _db = DatabaseService();
  List<Scenario> _scenarios = [];
  String _targetLang = 'ja';
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final syncing = context.watch<AuthProvider>().syncing;
    if (_wasSyncing && !syncing) {
      _load();
    }
    _wasSyncing = syncing;
  }

  Future<void> _load() async {
    final lang = await _db.getSetting(_scenarioLangKey);
    final list = await _db.getAllScenarios();
    if (!mounted) return;
    setState(() {
      _targetLang = lang ?? 'ja';
      _scenarios = list;
    });
  }

  Future<void> _setLang(String code) async {
    await _db.setSetting(_scenarioLangKey, code);
    setState(() => _targetLang = code);
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建场景'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：餐厅、公共交通'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = Scenario(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertScenario(s);
    await _load();
  }

  Future<void> _rename(Scenario s) async {
    final controller = TextEditingController(text: s.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名场景'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == s.name) return;
    s.name = name;
    await _db.updateScenario(s);
    await _load();
  }

  Future<void> _delete(Scenario s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除场景"${s.name}"吗？\n场景内的所有句子都会一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.deleteScenario(s.id);
    await _load();
  }

  Future<void> _open(Scenario s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScenarioChatScreen(
          scenarioId: s.id,
          targetLang: _targetLang,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('目标语言：'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _targetLang,
                  onChanged: (v) {
                    if (v != null) _setLang(v);
                  },
                  items: supportedLanguages.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text('${e.value.$1} ${e.value.$2}'),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _scenarios.isEmpty
                ? const Center(child: Text('点击右下角加号新建场景'))
                : ListView.separated(
                    itemCount: _scenarios.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final s = _scenarios[i];
                      return ListTile(
                        title: Text(s.name),
                        subtitle: Text('${s.sentences.length} 句'),
                        onTap: () => _open(s),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _rename(s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _delete(s),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
    );
  }
}
