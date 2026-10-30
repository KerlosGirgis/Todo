import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../view_model/auth_view_model.dart';
import '../screens/profile/lock_page/screen/lock_page.dart';

/// Keeps the App Lock over the app once it's open: tells [AuthViewModel]
/// when the app is put away and when it comes back, and whenever that locks
/// it again, covers the pages of [navigatorKey]'s navigator with the lock
/// page until it's unlocked, leaving them under it as they were.
class AppLockGuard extends StatefulWidget {
  const AppLockGuard({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AppLockGuard> createState() => _AppLockGuardState();
}

class _AppLockGuardState extends State<AppLockGuard> {
  late final AuthViewModel _auth;
  late final AppLifecycleListener _lifecycle;

  /// The lock page, while it's over the app's pages.
  Route<void>? _lockRoute;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>()..addListener(_lockChanged);
    _lifecycle = AppLifecycleListener(
      onHide: _auth.appHidden,
      onShow: _auth.appShown,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _auth.removeListener(_lockChanged);
    super.dispose();
  }

  void _lockChanged() {
    final navigator = widget.navigatorKey.currentState;
    // Before the app first opens, its pages aren't there yet: the lock page
    // is the start page then.
    final locked = _auth.opened && _auth.status != AuthStatus.authenticated;
    if (navigator == null || locked == (_lockRoute != null)) return;
    if (locked) {
      final route = _lockRoute = _lockPageRoute(_auth);
      navigator.push(route);
      // Only unlocking takes the lock page off. If anything else does, such
      // as a Navigator.pop meant for a page under it, it goes straight back.
      route.popped.whenComplete(() {
        if (!mounted || _lockRoute != route) return;
        _lockRoute = null;
        _lockChanged();
      });
    } else {
      final route = _lockRoute!;
      _lockRoute = null;
      if (route.isActive) navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The lock page, over the app's pages from the first frame it's in. Back
/// puts the app away, as Home does, rather than going back to a page under
/// it, or closing them all.
Route<void> _lockPageRoute(AuthViewModel auth) => PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) auth.putAway();
        },
        child: const LockPage(),
      ),
    );
