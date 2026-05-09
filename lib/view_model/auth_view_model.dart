import 'package:flutter/foundation.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/view_model/user_view_model.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthViewModel with ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  final AuthenticationService _authService = AuthenticationService();
  final DatabaseService _dbService = DatabaseService();

  Future<void> initializeApp(UserViewModel userViewModel) async {
    _status = AuthStatus.initializing;
    notifyListeners();
    final bool isAuthSuccess = await _authService.initializeApp();
    if (isAuthSuccess) {
      await _dbService.openDb();
      await VerseService.loadVerses();
      await userViewModel.get();
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> retryAuthentication(UserViewModel userViewModel) async {
    await initializeApp(userViewModel);
  }
}