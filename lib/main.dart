import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/models/widget_style.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/services/notification_service.dart';
import 'package:todo/view/widgets/app_gate.dart';
import 'package:todo/view/widgets/app_lock_guard.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/tour_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view_model/widgets_view_model.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await NotificationService.init();
  tz.initializeTimeZones();
  await NotificationService.followPhoneTimeZone();
  final launchedFrom = await _launchingWidget();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => UserViewModel()),
    // From the start, to follow the App Lock, which the reminders go by.
    ChangeNotifierProvider(create: (_) => TasksViewModel(), lazy: false),
    ChangeNotifierProvider(create: (_) => NotesViewModel()),
    ChangeNotifierProvider(create: (context) {
      final tasks = context.read<TasksViewModel>();
      final notes = context.read<NotesViewModel>();
      return AuthViewModel(
        context.read<UserViewModel>(),
        // Whichever page the app opens on: the to-do widget shows the tasks
        // as they are, and the settings count the tasks and the notes.
        onOpened: () => Future.wait([tasks.get(), notes.get()]),
      )..initializeApp();
    }),
    ChangeNotifierProvider(create: (_) => TourViewModel()),
    ChangeNotifierProvider(
        create: (_) => WidgetsViewModel(launchedFrom: launchedFrom)),
  ], child: const MyApp()));
}

/// The home screen widget a tap on which opened the app, if one did, for
/// the app to open on its page.
Future<WidgetKind?> _launchingWidget() async {
  try {
    return await HomeWidgetService().launchedFrom();
  } catch (e) {
    return null;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// The navigator of the app's pages, which the lock page goes over
  /// whenever the app locks again.
  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AppLockGuard(
      navigatorKey: _navigatorKey,
      child: Selector<UserViewModel, (bool, bool)>(
        selector: (_, userVM) =>
            (userVM.user.darkTheme, userVM.user.amoledTheme),
        builder: (context, theme, _) {
          final (isDarkMode, isAmoled) = theme;
          return ToastificationWrapper(
            child: MaterialApp(
              navigatorKey: _navigatorKey,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getTheme(isDarkMode: isDarkMode, isAmoled: isAmoled),
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate
              ],
              // The note editor's flutter_quill is still built on
              // flutter/material.dart, whose widgets look for that library's
              // own theme and localizations. The bridge hands them the app's.
              // Above the navigator, so menus quill opens in the overlay, like
              // copy and paste, find them too.
              builder: (context, child) =>
                  // ignore: deprecated_member_use
                  MaterialUiCompatibilityBridge(child: child!),
              home: Consumer2<AuthViewModel, UserViewModel>(
                builder: (context, auth, user, _) {
                  return AppGate(auth: auth, user: user);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
