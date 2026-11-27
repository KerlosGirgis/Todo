import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:toastification/toastification.dart';

import 'core/theme/app_theme.dart';
import 'models/widget_style.dart';
import 'services/authentication_service.dart';
import 'services/backup_service.dart';
import 'services/database_service.dart';
import 'services/device_service.dart';
import 'services/file_service.dart';
import 'services/home_widget_service.dart';
import 'services/image_service.dart';
import 'services/lock_service.dart';
import 'services/notification_service.dart';
import 'services/tour_service.dart';
import 'services/verse_service.dart';
import 'view/widgets/app_gate.dart';
import 'view/widgets/app_lock_guard.dart';
import 'view_model/auth_view_model.dart';
import 'view_model/notes_view_model.dart';
import 'view_model/tasks_view_model.dart';
import 'view_model/tour_view_model.dart';
import 'view_model/user_view_model.dart';
import 'view_model/widgets_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final services = _AppServices();
  await NotificationService.init();
  tz.initializeTimeZones();
  await NotificationService.followPhoneTimeZone(device: services.device);
  final launchedFrom = await _launchingWidget(services.homeWidgets);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserViewModel(
            imageService: services.images,
            lockService: services.lock,
            authService: services.auth,
            deviceService: services.device,
            verseService: services.verses,
            databaseService: services.database,
          ),
        ),
        // From the start, to follow the App Lock, which the reminders go by.
        ChangeNotifierProvider(
          create: (_) => TasksViewModel(
            backupService: services.backups,
            fileService: services.files,
            lockService: services.lock,
            authService: services.auth,
            notificationService: services.notifications,
            homeWidgetService: services.homeWidgets,
          ),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => NotesViewModel(
            authService: services.auth,
            lockService: services.lock,
            homeWidgetService: services.homeWidgets,
            backupService: services.backups,
            fileService: services.files,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final tasks = context.read<TasksViewModel>();
            final notes = context.read<NotesViewModel>();
            return AuthViewModel(
              context.read<UserViewModel>(),
              authService: services.auth,
              lockService: services.lock,
              databaseService: services.database,
              deviceService: services.device,
              verseService: services.verses,
              // Whichever page the app opens on: the to-do widget shows the tasks
              // as they are, and the settings count the tasks and the notes.
              onOpened: () => Future.wait([tasks.get(), notes.get()]),
            )..initializeApp();
          },
        ),
        ChangeNotifierProvider(
          create: (_) => TourViewModel(service: services.tours),
        ),
        ChangeNotifierProvider(
          create: (_) => WidgetsViewModel(
            service: services.homeWidgets,
            launchedFrom: launchedFrom,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// The services the app runs on, each made the once, here, and handed to
/// every view model that uses it, so that they all go by the same ones,
/// rather than each making its own.
class _AppServices {
  final device = DeviceService();
  final lock = LockService();
  late final auth = AuthenticationService(lockService: lock);
  final database = DatabaseService();
  final verses = VerseService();
  final images = ImageService();
  final notifications = NotificationService();
  final homeWidgets = HomeWidgetService();
  final backups = BackupService();
  final files = FileService();
  final tours = TourService();
}

/// The home screen widget a tap on which opened the app, if one did, for
/// the app to open on its page, as [homeWidgets] tells it.
Future<WidgetKind?> _launchingWidget(HomeWidgetService homeWidgets) async {
  try {
    return await homeWidgets.launchedFrom();
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
              theme: AppTheme.getTheme(
                isDarkMode: isDarkMode,
                isAmoled: isAmoled,
              ),
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              // The note editor's flutter_quill is still built on
              // flutter/material.dart, whose widgets look for that library's
              // own theme and localizations. The bridge hands them the app's.
              // Above the navigator, so menus quill opens in the overlay, like
              // copy and paste, find them too.
              builder: (context, child) =>
                  // ignore: deprecated_member_use
                  MaterialUiCompatibilityBridge(child: child!),
              home: const AppGate(),
            ),
          );
        },
      ),
    );
  }
}
