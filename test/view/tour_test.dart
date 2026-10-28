import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/view/widgets/tour.dart';

void main() {
  late TourController tour;
  late int ended;
  late GlobalKey first;
  late GlobalKey second;

  setUp(() {
    tour = TourController();
    ended = 0;
    first = GlobalKey();
    second = GlobalKey();
  });

  tearDown(() => tour.dispose());

  Future<void> showPage(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: false),
          home: Tour(
            controller: tour,
            child: Scaffold(
              body: Column(
                children: [
                  const SizedBox(height: 200),
                  SizedBox(key: first, width: 120, height: 60),
                  const SizedBox(height: 200),
                  SizedBox(key: second, width: 120, height: 60),
                ],
              ),
            ),
          ),
        ),
      );

  TourStep step(GlobalKey target, String title, {TourDemo? demo}) => TourStep(
        target: target,
        icon: Icons.check_rounded,
        title: title,
        message: "About $title.",
        demo: demo,
      );

  /// Lets the spotlight and the tips get where they're going. The demos
  /// repeat for ever, so there's no settling.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('goes from step to step, and ends after the last',
      (tester) async {
    await showPage(tester);
    tour.start([step(first, "First"), step(second, "Second")],
        onEnd: () => ended++);
    await settle(tester);
    expect(find.text("First"), findsOneWidget);
    expect(find.text("Skip"), findsOneWidget);

    await tester.tap(find.text("Next"));
    await settle(tester);
    expect(find.text("First"), findsNothing);
    expect(find.text("Second"), findsOneWidget);
    // Nothing to skip on the last step.
    expect(find.text("Skip"), findsNothing);

    await tester.tap(find.text("Done"));
    await settle(tester);
    expect(find.text("Second"), findsNothing);
    expect(tour.isActive, isFalse);
    expect(ended, 1);
  });

  testWidgets('skips a step whose target is not on the page', (tester) async {
    await showPage(tester);
    tour.start([
      step(first, "First"),
      step(GlobalKey(), "Missing"),
      step(second, "Second"),
    ]);
    await settle(tester);
    await tester.tap(find.text("Next"));
    await settle(tester);
    expect(find.text("Missing"), findsNothing);
    expect(find.text("Second"), findsOneWidget);
  });

  testWidgets('a tap on the page goes on, and Skip ends the tour',
      (tester) async {
    await showPage(tester);
    tour.start([
      step(first, "First"),
      step(second, "Second"),
      step(first, "Third"),
    ], onEnd: () => ended++);
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(find.text("Second"), findsOneWidget);

    await tester.tap(find.text("Skip"));
    await settle(tester);
    expect(find.text("Second"), findsNothing);
    expect(find.text("Third"), findsNothing);
    expect(ended, 1);
  });

  testWidgets('Back ends the tour, rather than leaving the page',
      (tester) async {
    await showPage(tester);
    tour.start([step(first, "First"), step(second, "Second")],
        onEnd: () => ended++);
    await settle(tester);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.text("First"), findsNothing);
    expect(ended, 1);
  });

  testWidgets('a demo acts its gestures out on its copy', (tester) async {
    await showPage(tester);
    tour.start([
      step(
        first,
        "Tap",
        demo: TourDemo(
          gestures: const [TourGesture.tap, TourGesture.tap],
          builder: (context, pose) =>
              SizedBox(height: 60, child: Text("Tapped ${pose.acted}")),
        ),
      ),
    ]);
    await tester.pump();
    expect(find.text("Tapped 0"), findsOneWidget);

    // A pause, the finger coming down, and its first tap.
    await tester.pump(const Duration(milliseconds: 450 + 320 + 130 + 50));
    expect(find.text("Tapped 1"), findsOneWidget);

    // The second tap, after the first one's ripple and a pause.
    await tester.pump(const Duration(milliseconds: 350 + 650 + 250 + 130 + 50));
    expect(find.text("Tapped 2"), findsOneWidget);
  });
}
