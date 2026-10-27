import 'package:material_ui/material_ui.dart';
import 'package:todo/view/widgets/loading.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../models/user_profile.dart';
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
    // Once the app has opened, it stays open under the lock page whenever
    // it locks again: see AppLockGuard.
    if (auth.opened) {
      return switch (user.user.startPage) {
        StartPage.tasks => const TodoPage(),
        StartPage.notes => const NotesPage(),
      };
    }
    if (auth.status == AuthStatus.unauthenticated) {
      return const LockPage();
    }
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: const Loading(),
    );
  }
}
