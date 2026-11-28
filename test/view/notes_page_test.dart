import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/services/tour_service.dart';
import 'package:todo/view/screens/notes/notes_page/screen/notes_page.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/tour_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view_model/widgets_view_model.dart';

import '../view_model/notes_view_model_test.dart' as notes_test;
import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository, FakeVerses, newLock;
import '../view_model/widgets_view_model_test.dart' show FakeWidgets;

void main() {
  late notes_test.FakeNotesRepository rows;
  late NotesViewModel notes;
  late TourViewModel tours;
  late WidgetsViewModel widgets;

  /// Lets [duration] go by a frame at a time, as it does on a phone, for the
  /// animations in it.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  /// Opens the notes page, with no notes, which can't be read in when
  /// [unreadable]. Every tour counts as seen, unless the page's is [due].
  Future<void> open(
    WidgetTester tester, {
    bool due = false,
    bool unreadable = false,
  }) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      for (final tour in PageTour.values)
        if (!(due && tour == PageTour.notes)) 'tour.${tour.name}': tour.version,
    });
    final user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    rows = notes_test.FakeNotesRepository()..failReads = unreadable;
    notes = NotesViewModel(
      repository: rows,
      authService: notes_test.FakeAuth(),
      lockService: notes_test.FakeLock(),
      homeWidgetService: notes_test.FakeHomeWidget(),
    );
    tours = TourViewModel(service: TourService());
    widgets = WidgetsViewModel(service: FakeWidgets());
    final auth = AuthViewModel(
      user,
      lockService: newLock(),
      databaseService: FakeDatabase(),
      deviceService: FakeDevice(),
      verseService: FakeVerses(),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: widgets),
          ChangeNotifierProvider.value(value: tours),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const NotesPage(),
          ),
        ),
      ),
    );
  }

  /// Lets the toasts close, then closes the page and lets the view models
  /// go, with their timers.
  Future<void> close(WidgetTester tester) async {
    await wait(tester, const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    notes.dispose();
    widgets.dispose();
  }

  testWidgets("the tour shows the first time the page opens, once it has "
      "risen in, and is seen once it ends", (tester) async {
    await open(tester, due: true);
    await wait(tester, const Duration(milliseconds: 500));
    expect(find.text("Open a Note"), findsNothing);
    await wait(tester, const Duration(seconds: 2));
    expect(find.text("Open a Note"), findsOneWidget);

    await tester.tap(find.text("Skip"));
    await wait(tester);
    expect(find.text("Open a Note"), findsNothing);
    final seen = await SharedPreferences.getInstance();
    expect(seen.getInt('tour.notes'), PageTour.notes.version);
    await close(tester);
  });

  testWidgets("a tour that's been seen shows again once the user asks for "
      "the tips again", (tester) async {
    await open(tester);
    await wait(tester, const Duration(seconds: 3));
    expect(find.text("Open a Note"), findsNothing);

    await tours.replay();
    await wait(tester, const Duration(seconds: 2));
    expect(find.text("Open a Note"), findsOneWidget);
    await tester.tap(find.text("Skip"));
    await close(tester);
  });

  testWidgets("no tour over notes that couldn't be read in", (tester) async {
    await open(tester, due: true, unreadable: true);
    await wait(tester, const Duration(seconds: 3));
    expect(find.text("Open a Note"), findsNothing);
    await close(tester);
  });

  testWidgets("the menu's Restore Backup offers to replace the notes or add "
      "to them", (tester) async {
    await open(tester);
    await wait(tester, const Duration(seconds: 2));
    await tester.tap(find.byTooltip("Menu"));
    await wait(tester);
    await tester.tap(find.byTooltip("Restore Backup"));
    await wait(tester);
    expect(find.text("Import notes from a backup file."), findsOneWidget);
    expect(find.text("Replace My Notes"), findsOneWidget);
    await tester.tap(find.text("Cancel"));
    await close(tester);
  });
}
