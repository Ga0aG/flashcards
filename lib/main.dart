import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 启用 Firestore 离线持久化：
  // - Web 端使用 IndexedDB 缓存（数据库.txt即为它，自动管理）
  // - 移动端默认就开启，但显式设置一下也没坏处
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('[Firestore] 设置 persistence 失败（可能已初始化）: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const FlashcardsApp(),
    ),
  );
}

class FlashcardsApp extends StatelessWidget {
  const FlashcardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flashcards',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// 登录守卫：未登录时显示登录页，登录后再进入主页。
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.syncing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!auth.isLoggedIn) {
      return const _LoginScreen();
    }
    return const HomeScreen();
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style, size: 72, color: Colors.blue),
              const SizedBox(height: 16),
              const Text('Flashcards',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('登录后才能使用，数据将云端同步',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('使用 Google 登录'),
                onPressed: auth.syncing ? null : () => auth.signIn(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
