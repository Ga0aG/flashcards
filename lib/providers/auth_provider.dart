import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _db = DatabaseService();
  final _sync = SyncService();

  User? _user;
  bool _syncing = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get syncing => _syncing;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (_user?.uid == user?.uid) return;
    _user = user;
    _db.setFirestoreUser(user?.uid);
    if (user != null) {
      _syncing = true;
      notifyListeners();
      try {
        await _sync.migrateIfNeeded(user.uid);
        await _sync.pullLatest(user.uid);
      } finally {
        _syncing = false;
      }
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    await _authService.signInWithGoogle();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
