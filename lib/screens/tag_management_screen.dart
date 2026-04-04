import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/wordbook.dart';

class TagManagementScreen extends StatefulWidget {
  final WordBook wordBook;
  const TagManagementScreen({super.key, required this.wordBook});

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  final _dbService = DatabaseService();
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await _dbService.getAllTags(widget.wordBook.id);
    setState(() => _tags = tags);
  }

  Future<void> _renameTag(String oldTag) async {
    final controller = TextEditingController(text: oldTag);
    final newTag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '新标签名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (newTag == null || newTag.isEmpty || newTag == oldTag) return;
    await _dbService.renameTag(widget.wordBook.id, oldTag, newTag);
    _loadTags();
  }

  Future<void> _deleteTag(String tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除标签"$tag"后，所有含此标签的单词都会移除该标签，确定吗？'),
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
    if (confirm != true) return;
    await _dbService.deleteTag(widget.wordBook.id, tag);
    _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      body: _tags.isEmpty
          ? const Center(child: Text('暂无标签'))
          : ListView.builder(
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                return ListTile(
                  title: Text(tag),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: '重命名',
                        onPressed: () => _renameTag(tag),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: '删除',
                        onPressed: () => _deleteTag(tag),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
