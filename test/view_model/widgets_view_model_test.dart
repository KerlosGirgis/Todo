import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/models/widget_look.dart';
import 'package:todo/models/widget_style.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/view_model/widgets_view_model.dart';

/// The phone's widgets, in memory.
class FakeWidgets extends HomeWidgetService {
  final styles = <WidgetKind, WidgetStyle>{};
  final added = <WidgetKind>[];
  final tapped = StreamController<WidgetKind>.broadcast();
  bool failSaving = false;
  bool canAdd = true;
  String? noteText;
  WidgetLook given = const WidgetLook(radius: 20, wallpaper: [0xff3a5f8f]);

  @override
  Future<WidgetStyle> styleOf(WidgetKind kind) async =>
      styles[kind] ?? WidgetStyle.defaultFor(kind);

  @override
  Future<void> setStyle(WidgetKind kind, WidgetStyle style) async {
    if (failSaving) throw StateError("Storage full");
    styles[kind] = style;
  }

  @override
  Future<bool> canAddWidget() async => canAdd;

  @override
  Future<void> addWidget(WidgetKind kind) async => added.add(kind);

  @override
  Future<WidgetLook> look() async => given;

  @override
  Future<({int? id, String? text})> shownNote() async =>
      (id: noteText == null ? null : 1, text: noteText);

  @override
  Future<void> clearNote() async {
    if (failSaving) throw StateError("Storage full");
    noteText = null;
  }

  @override
  Stream<WidgetKind> get taps => tapped.stream;
}

void main() {
  late FakeWidgets phone;
  late WidgetsViewModel widgets;

  setUp(() {
    phone = FakeWidgets();
    widgets = WidgetsViewModel(service: phone);
  });

  tearDown(() => widgets.dispose());

  test(
    'reads in how the widgets look, and what the note widget shows',
    () async {
      phone.styles[WidgetKind.tasks] = const WidgetStyle(showDone: true);
      phone.noteText = "Weekend plans";
      var notified = 0;
      widgets.addListener(() => notified++);

      // As they first come, until then.
      expect(widgets.styleOf(WidgetKind.tasks), WidgetStyle.tasksDefault);
      await widgets.load();
      expect(
        widgets.styleOf(WidgetKind.tasks),
        const WidgetStyle(showDone: true),
      );
      expect(widgets.styleOf(WidgetKind.note), WidgetStyle.noteDefault);
      expect(widgets.look.radius, 20);
      expect(widgets.canAdd, isTrue);
      expect(widgets.noteText, "Weekend plans");
      expect(notified, 1);
    },
  );

  test('sets a widget\'s style', () async {
    const style = WidgetStyle(background: 0xff1e1e1e, opacity: 0.8);
    expect(await widgets.setStyle(WidgetKind.note, style), isA<Success>());
    expect(phone.styles[WidgetKind.note], style);
    expect(widgets.styleOf(WidgetKind.note), style);
  });

  test('keeps the style it had when the new one can\'t be set', () async {
    phone.failSaving = true;
    expect(
      await widgets.setStyle(WidgetKind.tasks, const WidgetStyle(opacity: 0)),
      isA<Failure>(),
    );
    expect(widgets.styleOf(WidgetKind.tasks), WidgetStyle.tasksDefault);
  });

  test('reads in afresh what the note widget shows', () async {
    await widgets.load();
    expect(widgets.noteText, isNull);
    var notified = 0;
    widgets.addListener(() => notified++);

    phone.noteText = "Weekend plans";
    await widgets.loadNote();
    expect(widgets.noteText, "Weekend plans");
    expect(notified, 1);
    // Nothing to say when it's the same.
    await widgets.loadNote();
    expect(notified, 1);
  });

  test('takes the note off the note widget', () async {
    phone.noteText = "Weekend plans";
    await widgets.load();
    final result = await widgets.clearNote();
    expect((result as Success).message, "Widget Cleared");
    expect(phone.noteText, isNull);
    expect(widgets.noteText, isNull);
  });

  test("keeps the note widget's note when it can't be taken off", () async {
    phone.noteText = "Weekend plans";
    await widgets.load();
    phone.failSaving = true;
    expect(await widgets.clearNote(), isA<Failure>());
    expect(widgets.noteText, "Weekend plans");
  });

  test('asks the phone to add a widget', () async {
    expect(await widgets.add(WidgetKind.tasks), isNull);
    expect(phone.added, [WidgetKind.tasks]);
  });

  group('a tap on a widget', () {
    test('that opened the app opens it on the widget\'s page', () {
      expect(widgets.launchPage, isNull);
      final launched = WidgetsViewModel(
        service: phone,
        launchedFrom: WidgetKind.note,
      );
      expect(launched.launchPage, StartPage.notes);
      launched.dispose();
    });

    test('with the app open asks for the widget\'s page', () async {
      final asked = <StartPage>[];
      widgets.pageRequests.listen(asked.add);
      phone.tapped
        ..add(WidgetKind.tasks)
        ..add(WidgetKind.note);
      await Future<void>.delayed(Duration.zero);
      expect(asked, [StartPage.tasks, StartPage.notes]);
    });
  });
}
