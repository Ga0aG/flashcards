import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dbService = DatabaseService();
  String _mainLanguage = 'zh-CN';
  int _defaultReviewCount = 20;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lang = await _dbService.getSetting('main_language');
    final count = await _dbService.getSetting('default_review_count');
    setState(() {
      _mainLanguage = lang ?? 'zh-CN';
      _defaultReviewCount = int.tryParse(count ?? '20') ?? 20;
    });
  }

  Future<void> _saveSettings() async {
    await _dbService.setSetting('main_language', _mainLanguage);
    await _dbService.setSetting('default_review_count', _defaultReviewCount.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('主语言'),
            subtitle: Text(_mainLanguage),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('选择主语言'),
                  children: ['zh-CN', 'en-US', 'ja-JP', 'ko-KR', 'fr-FR', 'de-DE']
                      .map((lang) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, lang),
                            child: Text(lang),
                          ))
                      .toList(),
                ),
              );
              if (result != null) {
                setState(() => _mainLanguage = result);
                _saveSettings();
              }
            },
          ),
          ListTile(
            title: const Text('默认复习数量'),
            subtitle: Text('$_defaultReviewCount 个单词'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final controller = TextEditingController(text: _defaultReviewCount.toString());
              final result = await showDialog<int>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('设置默认复习数量'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '输入数量'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
              if (result != null && result > 0) {
                setState(() => _defaultReviewCount = result);
                _saveSettings();
              }
            },
          ),
        ],
      ),
    );
  }
}
