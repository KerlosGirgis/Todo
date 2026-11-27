import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/services/tour_service.dart';
import 'package:todo/view/screens/profile/profile_page/screen/profile_page.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/progress_card.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/settings_sections.dart';
import 'package:todo/view/widgets/settings_group.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/tour_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view_model/widgets_view_model.dart';

import '../view_model/notes_view_model_test.dart'
    as notes_test
    show FakeAuth, FakeHomeWidget, FakeLock, FakeNotesRepository;
import '../view_model/tasks_view_model_test.dart'
    show FakeLock, FakeNotifications, FakeTasksRepository;
import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository, newLock;
import '../view_model/widgets_view_model_test.dart' show FakeWidgets;

void main() {
  /// Lets [duration] go by a frame at a time, as it does on a phone, for
  /// the animations in it: a single pump would draw only their first frame.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  testWidgets("turned on its side, the settings stay one column, clear of the "
      "camera", (tester) async {
    tester.view.physicalSize = const Size(600, 360) * 2;
    tester.view.devicePixelRatio = 2;
    // The camera's cutout down the left side, as the phone is turned.
    tester.view.padding = const FakeViewPadding(left: 45 * 2);
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    final tasks = TasksViewModel(
      repository: FakeTasksRepository(),
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
    );
    final notes = NotesViewModel(
      repository: notes_test.FakeNotesRepository(),
      authService: notes_test.FakeAuth(),
      lockService: notes_test.FakeLock(),
      homeWidgetService: notes_test.FakeHomeWidget(),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: tasks),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider(
            create: (_) => WidgetsViewModel(service: FakeWidgets()),
          ),
          ChangeNotifierProvider(
            create: (_) => TourViewModel(service: TourService()),
          ),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const ProfilePage(),
          ),
        ),
      ),
    );
    // The sections rise into place.
    await wait(tester, const Duration(seconds: 2));

    // The profile is as wide as the screen lets it be, clear of the cutout.
    final progress = tester.getRect(find.byType(ProgressCard));
    expect(progress.left, 16 + 45);
    expect(progress.right, 600 - 16);

    // The settings come under it, as wide as it, not beside it.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await wait(tester);
    final appearance = tester.getRect(find.byType(AppearanceSection));
    expect(
      appearance.top,
      greaterThan(tester.getRect(find.byType(ProgressCard)).bottom),
    );
    expect(appearance.left, progress.left);
    expect(appearance.right, progress.right);

    await tester.pumpWidget(const SizedBox());
    tasks.dispose();
    notes.dispose();
  });

  testWidgets("the tasks' and the notes' widgets each have a row that "
      "opens the sheet styling them", (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    final tasks = TasksViewModel(
      repository: FakeTasksRepository(),
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
    );
    final notes = NotesViewModel(
      repository: notes_test.FakeNotesRepository(),
      authService: notes_test.FakeAuth(),
      lockService: notes_test.FakeLock(),
      homeWidgetService: notes_test.FakeHomeWidget(),
    );
    final widgets = WidgetsViewModel(service: FakeWidgets());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: tasks),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: widgets),
          ChangeNotifierProvider(
            create: (_) => TourViewModel(service: TourService()),
          ),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const ProfilePage(),
          ),
        ),
      ),
    );
    await wait(tester, const Duration(seconds: 2));

    // Each row by what its subtitle says, as both are "Home Screen Widget".
    for (final (row, title) in [
      ("Your tasks on the home screen", "To-Do Widget"),
      ("A note on the home screen", "Note Widget"),
    ]) {
      await tester.scrollUntilVisible(
        find.text(row),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await wait(tester);
      expect(
        find.ancestor(
          of: find.text(row),
          matching: find.widgetWithText(InkWell, "Home Screen Widget"),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(row));
      await wait(tester);
      expect(find.text(title), findsOneWidget);
      // Back to the settings, the style untried.
      await tester.binding.handlePopRoute();
      await wait(tester);
      expect(find.text(title), findsNothing);
    }

    await tester.pumpWidget(const SizedBox());
    tasks.dispose();
    notes.dispose();
    widgets.dispose();
  });

  testWidgets(
    "a row under the note widget's says which note it shows, and takes it "
    "off",
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final user = UserViewModel(
        repository: FakeUserRepository(),
        lockService: newLock(),
        deviceService: FakeDevice(),
        databaseService: FakeDatabase(),
      );
      await user.get();
      final tasks = TasksViewModel(
        repository: FakeTasksRepository(),
        notificationService: FakeNotifications(),
        lockService: FakeLock(),
      );
      final notes = NotesViewModel(
        repository: notes_test.FakeNotesRepository(),
        authService: notes_test.FakeAuth(),
        lockService: notes_test.FakeLock(),
        homeWidgetService: notes_test.FakeHomeWidget(),
      );
      // Put there from the note's editor, since the widgets were last read.
      final phone = FakeWidgets()..noteText = "\nWeekend plans\nThe river walk";
      final widgets = WidgetsViewModel(service: phone);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: user),
            ChangeNotifierProvider.value(value: tasks),
            ChangeNotifierProvider.value(value: notes),
            ChangeNotifierProvider.value(value: widgets),
            ChangeNotifierProvider(
              create: (_) => TourViewModel(service: TourService()),
            ),
          ],
          child: ToastificationWrapper(
            child: MaterialApp(
              theme: AppTheme.getTheme(isDarkMode: false),
              home: const ProfilePage(),
            ),
          ),
        ),
      );
      await wait(tester, const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text("Clear Widget"),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await wait(tester);
      expect(find.text("Shows “Weekend plans”"), findsOneWidget);

      await tester.tap(find.text("Clear Widget"));
      // Through its toast.
      await wait(tester, const Duration(seconds: 6));
      expect(phone.noteText, isNull);
      expect(widgets.noteText, isNull);
      expect(find.text("No note on it now"), findsOneWidget);

      // With nothing on the widget, as far as it knows, the row does nothing.
      phone.noteText = "Put on it behind the row's back";
      await tester.tap(find.text("Clear Widget"));
      await wait(tester);
      expect(phone.noteText, "Put on it behind the row's back");

      await tester.pumpWidget(const SizedBox());
      tasks.dispose();
      notes.dispose();
      widgets.dispose();
    },
  );

  testWidgets("a setting that can't be saved says so, and stays as it was", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final rows = FakeUserRepository();
    final user = UserViewModel(
      repository: rows,
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    final tasks = TasksViewModel(
      repository: FakeTasksRepository(),
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
    );
    final notes = NotesViewModel(
      repository: notes_test.FakeNotesRepository(),
      authService: notes_test.FakeAuth(),
      lockService: notes_test.FakeLock(),
      homeWidgetService: notes_test.FakeHomeWidget(),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: tasks),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider(
            create: (_) => WidgetsViewModel(service: FakeWidgets()),
          ),
          ChangeNotifierProvider(
            create: (_) => TourViewModel(service: TourService()),
          ),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const ProfilePage(),
          ),
        ),
      ),
    );
    await wait(tester, const Duration(seconds: 2));
    await tester.scrollUntilVisible(
      find.text("Daily Verse"),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await wait(tester);

    // The disk is full.
    rows.failUpdates = true;
    await tester.tap(find.text("Daily Verse"));
    await wait(tester);
    expect(find.text("Couldn't change the setting"), findsOneWidget);
    expect(user.user.showVerse, isTrue);
    expect(
      tester
          .widget<SettingsSwitchTile>(
            find.widgetWithText(SettingsSwitchTile, "Daily Verse"),
          )
          .value,
      isTrue,
    );

    // Through its toast.
    await wait(tester, const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    tasks.dispose();
    notes.dispose();
  });
}
