import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/wordbook.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import 'wordbook_screen.dart';
import 'training_screen.dart';
import 'settings_screen.dart';

// Supported languages: code -> (flag emoji, display name)
const _languages = {
  'ja': ('🇯🇵', '日语'),
  'en': ('🇺🇸', '英语'),
  'zh': ('🇨🇳', '汉语'),
  'it': ('🇮🇹', '意大利语'),
  'es': ('🇪🇸', '西班牙语'),
};

String langFlag(String code) => _languages[code]?.$1 ?? '🌐';
String langName(String code) => _languages[code]?.$2 ?? code;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dbService = DatabaseService();
  List<WordBook> _wordbooks = [];
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadWordBooks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final syncing = context.watch<AuthProvider>().syncing;
    // 同步完成时刷新列表
    if (_wasSyncing && !syncing) {
      _loadWordBooks();
    }
    _wasSyncing = syncing;
  }

  Future<void> _loadWordBooks() async {
    try {
      final books = await _dbService.getAllWordBooks();
      setState(() => _wordbooks = books);
    } catch (e) {
      print('Error loading wordbooks: $e');
    }
  }

  Future<void> _createWordBook() async {
    String? selectedLang;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('选择学习语言'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: _languages.entries.map((entry) {
                final code = entry.key;
                final flag = entry.value.$1;
                final name = entry.value.$2;
                return RadioListTile<String>(
                  value: code,
                  groupValue: selectedLang,
                  title: Text('$flag $name'),
                  onChanged: (v) => setDialogState(() => selectedLang = v),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: selectedLang == null ? null : () => Navigator.pop(context, selectedLang),
                child: const Text('创建'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final newBook = WordBook(id: const Uuid().v4(), language: result, createdAt: now, updatedAt: now);
        await _dbService.insertWordBook(newBook);
        await _loadWordBooks();
      } catch (e) {
        print('Error creating wordbook: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单词本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _wordbooks.length,
        itemBuilder: (context, index) {
          final book = _wordbooks[index];
          return ListTile(
            leading: Text(langFlag(book.language), style: const TextStyle(fontSize: 32)),
            title: Text(langName(book.language)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WordBookScreen(wordBook: book))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.psychology),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TrainingScreen(wordBook: book))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text('确定要删除${langFlag(book.language)} ${langName(book.language)}单词本吗？\n此操作会删除其中所有单词。'),
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
                      await _dbService.deleteWordBook(book.id);
                      _loadWordBooks();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _createWordBook, child: const Icon(Icons.add)),
    );
  }
}
