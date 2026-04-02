import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/wordbook.dart';
import '../services/database_service.dart';
import 'wordbook_screen.dart';
import 'training_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dbService = DatabaseService();
  List<WordBook> _wordbooks = [];

  @override
  void initState() {
    super.initState();
    _loadWordBooks();
  }

  Future<void> _loadWordBooks() async {
    try {
      final books = await _dbService.getAllWordBooks();
      print('Loaded ${books.length} wordbooks');
      setState(() => _wordbooks = books);
    } catch (e) {
      print('Error loading wordbooks: $e');
    }
  }

  Future<void> _createWordBook() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建单词本'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: '单词本名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('创建')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final newBook = WordBook(id: const Uuid().v4(), name: result, createdAt: now, updatedAt: now);
        print('Creating wordbook: ${newBook.name}');
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
            title: Text(book.name),
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
                        content: Text('确定要删除单词本"${book.name}"吗？\n此操作会删除其中所有单词。'),
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
