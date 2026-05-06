import 'package:flutter/foundation.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/verse_manager.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthViewModel with ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  final AuthenticationService _authService = AuthenticationService();
  final DatabaseService _dbService = DatabaseService();

  Future<void> initializeApp() async {
    _status = AuthStatus.initializing;
    notifyListeners();
    final bool isAuthSuccess = await _authService.initializeApp();
    if (isAuthSuccess) {
      await _dbService.openDb();
      await VerseManager.loadVerses();
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> retryAuthentication() async {
    await initializeApp();
  }
}