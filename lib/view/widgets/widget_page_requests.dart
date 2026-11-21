import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../view_model/auth_view_model.dart';
import '../../view_model/widgets_view_model.dart';

/// Has one of the app's two pages, the to-do page or the notes page, go
/// over to the other when a tap on the other's home screen widget brings the
/// app back: straight away while the page is showing, or once the App Lock
/// lets the user back in, when the lock page is what's over it. Not from
/// under another page or a dialog, which the user was in the middle of.
mixin WidgetPageRequests<T extends StatefulWidget> on State<T> {
  /// The page this is.
  StartPage get widgetPage;

  /// Goes over to the other page.
  void openOtherPage();

  StreamSubscription<StartPage>? _requests;
  AuthViewModel? _auth;

  /// Whether a tap asked for the other page while the app was locked.
  bool _awaitingUnlock = false;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<AuthViewModel?>(context, listen: false);
    _requests = Provider.of<WidgetsViewModel?>(
      context,
      listen: false,
    )?.pageRequests.listen(_requested);
  }

  @override
  void dispose() {
    _requests?.cancel();
    _stopAwaitingUnlock();
    super.dispose();
  }

  void _requested(StartPage page) {
    if (!mounted) return;
    if (page == widgetPage) return _stopAwaitingUnlock();
    final auth = _auth;
    if (auth != null && auth.status != AuthStatus.authenticated) {
      if (!_awaitingUnlock) {
        _awaitingUnlock = true;
        auth.addListener(_lockChanged);
      }
      return;
    }
    _openIfShowing();
  }

  void _lockChanged() {
    if (_auth?.status != AuthStatus.authenticated) return;
    _stopAwaitingUnlock();
    // Once the lock page has gone from over it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openIfShowing());
  }

  void _stopAwaitingUnlock() {
    if (!_awaitingUnlock) return;
    _awaitingUnlock = false;
    _auth?.removeListener(_lockChanged);
  }

  void _openIfShowing() {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) openOtherPage();
  }
}
