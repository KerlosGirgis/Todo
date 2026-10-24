import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../models/app_lock.dart';
import '../../../../../view_model/auth_view_model.dart';
import '../../profile_page/widgets/profile_button.dart';
import '../widgets/password_field.dart';

class LockPage extends StatefulWidget {
  const LockPage({
    super.key,
  });

  @override
  State<LockPage> createState() => LockPageState();
}

class LockPageState extends State<LockPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.select<AuthViewModel, AppLock>((auth) => auth.lock);
    return Scaffold(
      // No back button over the app's pages, when it locks again with them
      // open.
      appBar: AppBar(automaticallyImplyLeading: false),
      body: lock == AppLock.password
          ? const _PasswordUnlock()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Image.asset("assets/locked.png"),
                  ),
                  Flexible(
                    child: IconButton(
                        onPressed: () async {
                          await Provider.of<AuthViewModel>(context,
                                  listen: false)
                              .retryAuthentication();
                        },
                        icon: const Icon(Icons.refresh_sharp,
                            size: 70, color: Color(0xff3D5AFE))),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The lock page of an app locked with a password: a field for it, and a
/// button that opens the app with it.
class _PasswordUnlock extends StatefulWidget {
  const _PasswordUnlock();

  @override
  State<_PasswordUnlock> createState() => _PasswordUnlockState();
}

class _PasswordUnlockState extends State<_PasswordUnlock> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final password = _controller.text;
    if (password.isEmpty || _checking) return;
    setState(() => _checking = true);
    final result = await context.read<AuthViewModel>().unlock(password);
    // Once it's right, the app opens in this page's place.
    if (!mounted || result is! Failure) return;
    HapticFeedback.heavyImpact();
    _controller.clear();
    setState(() {
      _checking = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
        // Loosens the width the scroll view gives it, so that it can be
        // narrower than a tablet.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset("assets/locked.png", height: 180),
                const SizedBox(height: 12),
                Text(
                  "Enter Your Password",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.wB,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 22),
                PasswordField(
                  controller: _controller,
                  hint: "Password",
                  autofocus: true,
                  error: _error,
                  onSubmitted: _unlock,
                ),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, child) => ProfileButton(
                    label: "Unlock",
                    onPressed:
                        _controller.text.isEmpty || _checking ? null : _unlock,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
