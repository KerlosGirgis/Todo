import 'package:flutter/material.dart';
import 'package:todo/view/widgets/loading.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../view_model/auth_view_model.dart';
import '../../view_model/user_view_model.dart';
import '../screens/notes/notes_page/screen/notes_page.dart';
import '../screens/profile/lock_page/screen/lock_page.dart';
import '../screens/tasks/todo_page/screen/todo_page.dart';

class AppGate extends StatelessWidget {
  final AuthViewModel auth;
  final UserViewModel user;

  const AppGate({
    super.key,
    required this.auth,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (auth.status == AuthStatus.initializing) {
      return Scaffold(
        backgroundColor: context.colors.pageBackground,
        body: const Loading(),
      );
    }

    if (auth.status == AuthStatus.unauthenticated) {
      return const LockPage();
    }
    return user.user.startPage == 0 ? const TodoPage() : const NotesPage();
  }
}
