import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/tasks_widget_snapshot.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/widget_look.dart';
import 'package:todo/models/widget_style.dart';
import 'package:todo/services/home_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const homeWidget = MethodChannel('home_widget');
  const widgets = MethodChannel('com.k.todo/widgets');

  /// The widgets' storage, as the phone keeps it, and the widgets told to
  /// draw themselves again.
  late Map<String, Object?> stored;
  late List<String?> updated;
  late String? launchedWith;

  setUp(() {
    stored = {};
    updated = [];
    launchedWith = null;
    messenger.setMockMethodCallHandler(homeWidget, (call) async {
      final arguments = call.arguments as Map?;
      switch (call.method) {
        case 'saveWidgetData':
          final data = arguments!['data'];
          if (data == null) {
            stored.remove(arguments['id']);
          } else {
            stored[arguments['id'] as String] = data;
          }
          return true;
        case 'getWidgetData':
          return stored[arguments!['id']] ?? arguments['defaultValue'];
        case 'updateWidget':
          updated.add(arguments!['android'] as String?);
          return true;
        case 'initiallyLaunchedFromHomeWidget':
          return launchedWith;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(homeWidget, null);
    messenger.setMockMethodCallHandler(widgets, null);
  });

  final service = HomeWidgetService();

  group('a widget\'s style', () {
    test('is kept as JSON, and the widgets draw themselves again', () async {
      const style = WidgetStyle(background: 0xff1e1e1e, showDone: true);
      await service.setStyle(WidgetKind.tasks, style);
      expect(jsonDecode(stored['tasksWidgetStyle'] as String), style.toJson());
      expect(updated, ["Tasks"]);
      expect(await service.styleOf(WidgetKind.tasks), style);
    });

    test('is as the widget first comes before it\'s set', () async {
      expect(await service.styleOf(WidgetKind.tasks), WidgetStyle.tasksDefault);
      expect(await service.styleOf(WidgetKind.note), WidgetStyle.noteDefault);
    });

    test('for the note widget, keeps its size and font from before', () async {
      stored['widgetTextSize'] = "1.25";
      stored['useCasualFont'] = true;
      expect(
        await service.styleOf(WidgetKind.note),
        const WidgetStyle(opacity: 0, textSize: 1.25, font: WidgetFont.casual),
      );
      // Until it has a style of its own.
      await service.setStyle(WidgetKind.note, WidgetStyle.noteDefault);
      expect(await service.styleOf(WidgetKind.note), WidgetStyle.noteDefault);
      expect(updated, ["Note"]);
    });

    test('that can\'t be read is as the widget first comes', () async {
      stored['tasksWidgetStyle'] = "{not json";
      expect(await service.styleOf(WidgetKind.tasks), WidgetStyle.tasksDefault);
    });
  });

  test('the tasks go to the to-do widget as their snapshot', () async {
    final snapshot = TasksWidgetSnapshot.of([
      TodoItem(uuid: "a", title: "Water the plants"),
    ], now: DateTime(2026, 5, 13, 12));
    await service.showTasks(snapshot);
    expect(stored['tasks'], snapshot.encode());
    expect(updated, ["Tasks"]);
  });

  test('the note widget still keeps its note and the note\'s id', () async {
    await service.showNote(4, "Weekend plans");
    expect(await service.shownNote(), (id: 4, text: "Weekend plans"));
    expect(updated, ["Note"]);
    await service.clearNote();
    expect(await service.shownNote(), (id: null, text: null));
  });

  group('how the phone draws widgets', () {
    test('comes from the app\'s own channel', () async {
      messenger.setMockMethodCallHandler(widgets, (call) async {
        expect(call.method, "look");
        return {
          'radius': 28.0,
          'light': {
            'background': 0xfff4eff4 - 0x100000000,
            'text': 0xff1c1b1f - 0x100000000,
            'secondary': 0xff49454f - 0x100000000,
            'note': 0x61000000,
          },
          'dark': {
            'background': 0xff1c1b1f - 0x100000000,
            'text': 0xffe6e1e5 - 0x100000000,
          },
          'wallpaper': [0xff3a5f8f - 0x100000000, null],
          'sizes': {
            'Tasks': [276, 232],
            'Note': null,
          },
        };
      });
      final look = await service.look();
      expect(look.radius, 28);
      expect(look.light.background, 0xfff4eff4);
      expect(look.light.noteText, 0x61000000);
      expect(look.dark.text, 0xffe6e1e5);
      // What it leaves out is as near as the app can tell.
      expect(look.dark.secondaryText, WidgetLook.darkFallback.secondaryText);
      expect(look.wallpaper, [0xff3a5f8f]);
      expect(look.sizes, {WidgetKind.tasks: (width: 276.0, height: 232.0)});
    });

    test('is as near as the app can tell without it', () async {
      final look = await service.look();
      expect(look.light.background, WidgetLook.lightFallback.background);
      expect(look.sizes, isEmpty);
    });
  });

  test('a tap on a widget opens the app on its page', () async {
    expect(await service.launchedFrom(), isNull);
    launchedWith = "todo://tasks";
    expect(await service.launchedFrom(), WidgetKind.tasks);
    launchedWith = "todo://note";
    expect(await service.launchedFrom(), WidgetKind.note);
    launchedWith = "elsewhere://tasks";
    expect(await service.launchedFrom(), isNull);
  });
}
