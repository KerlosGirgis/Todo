import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/widget_look.dart';
import 'package:todo/models/widget_style.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/widget_previews.dart';
import 'package:todo/view/widgets/color_swatches.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/widget_style_sheet.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view_model/widgets_view_model.dart';

import '../view_model/tasks_view_model_test.dart' show FakeLock;
import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository;
import '../view_model/widgets_view_model_test.dart' show FakeWidgets;

/// How the phone draws widgets, in colours a test can tell apart.
const look = WidgetLook(
  radius: 28,
  light: WidgetThemeColors(
    background: 0xfff4eff4,
    text: 0xff1c1b1f,
    secondaryText: 0xff49454f,
    noteText: 0x61000000,
  ),
  dark: WidgetThemeColors(
    background: 0xff1c1b1f,
    text: 0xffe6e1e5,
    secondaryText: 0xffcac4d0,
    noteText: 0x80ffffff,
  ),
);

void main() {
  late FakeWidgets phone;
  late WidgetsViewModel widgets;
  late UserViewModel user;
  late FakeLock lock;

  /// Lets [duration] go by a frame at a time, for the sheet's and the
  /// toasts' animations.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    phone = FakeWidgets()
      ..given = look
      ..noteText = "Weekend plans";
    widgets = WidgetsViewModel(service: phone);
    lock = FakeLock();
    user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: lock,
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
  });

  tearDown(() => widgets.dispose());

  /// Opens [kind]'s sheet on a phone held upright, from a page with a button
  /// that opens it.
  Future<void> open(
    WidgetTester tester,
    WidgetKind kind, {
    Size size = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await user.get();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: widgets),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showWidgetStyleSheet(context, kind),
                    child: const Text("Open"),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open"));
    await wait(tester);
  }

  /// The preview's to-do widget.
  TasksWidgetContent tasksPreview(WidgetTester tester) =>
      tester.widget(find.byType(TasksWidgetContent));

  Future<void> tapRow(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await wait(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text(title));
    await wait(tester, const Duration(milliseconds: 400));
  }

  testWidgets("the to-do widget's preview shows the tasks still to do, and "
      "the done ones once they're shown", (tester) async {
    await open(tester, WidgetKind.tasks);
    expect(find.text("To-Do Widget"), findsOneWidget);
    expect(find.text("Water the plants"), findsOneWidget);
    expect(find.text("Eggs"), findsNothing);
    expect(find.text("Yesterday, 10:00 AM"), findsOneWidget);
    // Unchanged, there's nothing to apply.
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text("Apply"),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tapRow(tester, "Show Done Tasks");
    expect(find.text("Eggs"), findsOneWidget);

    await tester.tap(find.text("Apply"));
    await wait(tester);
    expect(phone.styles[WidgetKind.tasks], const WidgetStyle(showDone: true));
    expect(find.text("To-Do Widget"), findsNothing);
    expect(find.text("Widget Updated"), findsOneWidget);
    await wait(tester, const Duration(seconds: 5));
  });

  testWidgets("a background of its own makes the automatic text stand out "
      "against it, and Reset takes it back", (tester) async {
    await open(tester, WidgetKind.tasks);
    // On the phone's own background, in the phone's colours.
    expect(tasksPreview(tester).colors.text, look.light.text);
    final title = find.descendant(
      of: find.byType(TasksWidgetContent),
      matching: find.text("To-Do"),
    );
    expect(tester.widget<Text>(title).style!.color, Color(look.light.text));

    await tapRow(tester, "Background");
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is SwatchButton && widget.label == "Graphite",
      ),
    );
    await wait(tester, const Duration(milliseconds: 300));
    expect(
      tester.widget<Text>(title).style!.color,
      const Color(WidgetStyle.lightInk),
    );

    await tester.ensureVisible(find.text("Reset"));
    await tester.tap(find.text("Reset"));
    await wait(tester, const Duration(milliseconds: 300));
    expect(tester.widget<Text>(title).style!.color, Color(look.light.text));
    await tester.tap(find.text("Apply"), warnIfMissed: false);
    await wait(tester);
    // Back as it was, there was nothing to apply.
    expect(phone.styles, isEmpty);
  });

  testWidgets("the preview switches to dark mode, as the phone would", (
    tester,
  ) async {
    await open(tester, WidgetKind.tasks);
    expect(tasksPreview(tester).colors, same(look.light));
    await tester.tap(find.text("Dark"));
    await wait(tester, const Duration(milliseconds: 400));
    expect(tasksPreview(tester).colors, same(look.dark));
  });

  testWidgets("the note widget's preview has its note, in the font picked", (
    tester,
  ) async {
    await open(tester, WidgetKind.note);
    expect(find.text("Note Widget"), findsOneWidget);
    final note = find.descendant(
      of: find.byType(NoteWidgetContent),
      matching: find.text("Weekend plans"),
    );
    expect(tester.widget<Text>(note).style!.fontFamily, isNot('casual'));
    // In the colour it's always been, with no background of its own.
    expect(tester.widget<Text>(note).style!.color, Color(look.light.noteText));
    expect(find.text("Show Done Tasks"), findsNothing);
    expect(find.text("Accent Color"), findsNothing);

    await tester.ensureVisible(find.text("Casual"));
    await tester.tap(find.text("Casual"));
    await wait(tester, const Duration(milliseconds: 400));
    expect(tester.widget<Text>(note).style!.fontFamily, 'casual');

    await tester.tap(find.text("Apply"));
    await wait(tester);
    expect(
      phone.styles[WidgetKind.note],
      WidgetStyle.noteDefault.copyWith(font: WidgetFont.casual),
    );
    await wait(tester, const Duration(seconds: 5));
  });

  testWidgets("Add Widget asks the phone for one, styled as the sheet has it", (
    tester,
  ) async {
    await open(tester, WidgetKind.tasks);
    await tapRow(tester, "Show Done Tasks");
    await tester.tap(find.text("Add Widget"));
    await wait(tester);
    expect(phone.styles[WidgetKind.tasks], const WidgetStyle(showDone: true));
    expect(phone.added, [WidgetKind.tasks]);
    expect(find.text("To-Do Widget"), findsNothing);
    await wait(tester, const Duration(seconds: 5));
  });

  testWidgets("there's no Add Widget where the phone can't add one", (
    tester,
  ) async {
    phone.canAdd = false;
    await open(tester, WidgetKind.tasks);
    expect(find.text("Add Widget"), findsNothing);
    expect(find.text("Apply"), findsOneWidget);
  });

  testWidgets("says what the widget shows while the App Lock is on", (
    tester,
  ) async {
    await open(tester, WidgetKind.tasks);
    expect(find.textContaining("App Lock"), findsNothing);
    await tester.pumpWidget(const SizedBox());

    lock.lock = AppLock.password;
    await open(tester, WidgetKind.tasks);
    expect(find.textContaining("While the App Lock is on"), findsOneWidget);
  });

  testWidgets("on a phone turned on its side, the whole sheet scrolls", (
    tester,
  ) async {
    await open(tester, WidgetKind.tasks, size: const Size(2400, 1080));
    expect(tester.takeException(), isNull);
    await tapRow(tester, "Show Done Tasks");
    expect(find.text("Eggs"), findsOneWidget);
    await tester.ensureVisible(find.text("Apply"));
    await tester.tap(find.text("Apply"));
    await wait(tester);
    expect(phone.styles[WidgetKind.tasks], const WidgetStyle(showDone: true));
    await wait(tester, const Duration(seconds: 5));
  });
}
