import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../models/user_profile.dart';
import '../../view_model/auth_view_model.dart';
import '../../view_model/widgets_view_model.dart';
import '../screens/notes/notes_page/screen/notes_page.dart';
import '../screens/profile/lock_page/screen/lock_page.dart';
import '../screens/tasks/todo_page/screen/todo_page.dart';
import 'loading.dart';
import 'profile_button.dart';

/// The app's home: the lock page, or what it shows while it opens, or
/// can't, then the page it opens on.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    // Once the app has opened, it stays open under the lock page whenever
    // it locks again: see AppLockGuard.
    if (auth.opened) {
      // A widget's page, for an app its tap opened, or else the start page
      // the app opened with. Neither changes while the app runs, so a start
      // page picked in the settings doesn't swap the page under them.
      final launchPage = Provider.of<WidgetsViewModel?>(
        context,
        listen: false,
      )?.launchPage;
      return pageFor(launchPage ?? auth.openedOn);
    }
    if (auth.status == AuthStatus.unauthenticated) {
      return const LockPage();
    }
    if (auth.status == AuthStatus.failed) {
      return _OpenFailed(onRetry: auth.retryAuthentication);
    }
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: const Loading(),
    );
  }
}

/// The page the app shows for [page]: the to-do page, or the notes.
Widget pageFor(StartPage page) => switch (page) {
  StartPage.tasks => const TodoPage(),
  StartPage.notes => const NotesPage(),
};

/// Puts [page] in place of the page [context] is on, as each page's switch
/// button does, sliding it in from its side: the notes from the left, the
/// to-do page from the right. Through here, rather than the pages knowing
/// each other.
void switchToPage(BuildContext context, StartPage page) {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => pageFor(page),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: animation.drive(
              Tween(
                begin: Offset(page == StartPage.notes ? -1 : 1, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.ease)),
            ),
            child: child,
          ),
    ),
  );
}

/// What the app shows when it can't open the tasks and notes, rather than
/// opening for good: why, and a way to try again.
class _OpenFailed extends StatelessWidget {
  const _OpenFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 72,
                    color: ink.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Couldn't Open Your Data",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Something went wrong while opening your tasks and notes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.6),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ProfileButton(
                    label: "Try Again",
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
