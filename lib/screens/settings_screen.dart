import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 账号区块 ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('账号与同步', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  if (auth.syncing)
                    const Row(
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('正在同步数据...'),
                      ],
                    )
                  else if (auth.isLoggedIn) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          child: auth.user?.photoURL != null
                              ? ClipOval(
                                  child: Image.network(
                                    auth.user!.photoURL!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person),
                                  ),
                                )
                              : const Icon(Icons.person),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(auth.user?.displayName ?? '已登录',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(auth.user?.email ?? '',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('数据已开启云端同步', style: TextStyle(fontSize: 12, color: Colors.green)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('退出登录'),
                            content: const Text('退出后数据仍保留在本地，但不再同步到云端。'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
                            ],
                          ),
                        );
                        if (confirm == true) auth.signOut();
                      },
                      child: const Text('退出登录'),
                    ),
                  ] else ...[
                    const Text('登录后可在多设备间同步单词本',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: auth.syncing ? null : () => auth.signIn(),
                      icon: const Icon(Icons.login),
                      label: const Text('使用 Google 账号登录'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── 语言和复习数量 ─────────────────────────────────
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
