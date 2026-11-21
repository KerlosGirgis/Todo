import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../core/tasks_widget_snapshot.dart';
import '../models/widget_look.dart';
import '../models/widget_style.dart';

/// The app's widgets on the home screen: the note widget and the to-do
/// widget. What they show, how they look, and which of them opened the app.
class HomeWidgetService {
  /// The app's own channel for what only the phone knows about its widgets.
  static const _channel = MethodChannel("com.k.todo/widgets");

  /// Where a tap on each widget opens the app: "todo://tasks" or
  /// "todo://note", as the phone's widgets have it.
  static const _scheme = "todo";

  /// Shows [text], the text of the note with [noteId], on the widget.
  Future<void> showNote(int noteId, String text) async {
    await HomeWidget.saveWidgetData<int>("noteId", noteId);
    await HomeWidget.saveWidgetData<String>("note", text);
    await HomeWidget.updateWidget(androidName: WidgetKind.note.androidName);
  }

  /// The note on the widget: its id, and the text of it the widget shows.
  /// Both are null with no note there, and the id is null for a note put
  /// there before the widget kept track of which note it shows.
  Future<({int? id, String? text})> shownNote() async => (
    id: await HomeWidget.getWidgetData<int>("noteId"),
    text: await HomeWidget.getWidgetData<String>("note"),
  );

  /// Has the widget keep track of the note it shows by [noteId], its id now.
  Future<void> followNote(int noteId) =>
      HomeWidget.saveWidgetData<int>("noteId", noteId);

  /// Takes the note off the widget, which goes back to saying "Note".
  Future<void> clearNote() async {
    await HomeWidget.saveWidgetData<int>("noteId", null);
    await HomeWidget.saveWidgetData<String>("note", null);
    await HomeWidget.updateWidget(androidName: WidgetKind.note.androidName);
  }

  /// Shows the tasks as [snapshot] has them on the to-do widget.
  Future<void> showTasks(TasksWidgetSnapshot snapshot) async {
    await HomeWidget.saveWidgetData<String>("tasks", snapshot.encode());
    await HomeWidget.updateWidget(androidName: WidgetKind.tasks.androidName);
  }

  /// How [kind] of widget looks: as its style was last set, or as it first
  /// comes. The note widget, before it had a style of its own, kept its
  /// text in the size and font the notes' settings last set, which it keeps
  /// until its style is set.
  Future<WidgetStyle> styleOf(WidgetKind kind) async {
    final defaults = WidgetStyle.defaultFor(kind);
    final saved = await HomeWidget.getWidgetData<String>(kind.styleKey);
    if (saved != null) {
      try {
        return WidgetStyle.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
          defaults: defaults,
        );
      } catch (e) {
        // Taken as it first comes, as the widget takes it too.
      }
    }
    if (kind == WidgetKind.note) {
      return WidgetStyle.legacyNote(
        textSize: await HomeWidget.getWidgetData<String>("widgetTextSize"),
        casualFont: await HomeWidget.getWidgetData<bool>("useCasualFont"),
      );
    }
    return defaults;
  }

  /// Has every widget of [kind] look as [style] has it.
  Future<void> setStyle(WidgetKind kind, WidgetStyle style) async {
    await HomeWidget.saveWidgetData<String>(
      kind.styleKey,
      jsonEncode(style.toJson()),
    );
    await HomeWidget.updateWidget(androidName: kind.androidName);
  }

  /// Whether the phone's home screen can take a widget the app adds.
  Future<bool> canAddWidget() async =>
      await HomeWidget.isRequestPinWidgetSupported() ?? false;

  /// Asks the phone to add [kind] of widget to the home screen, which it
  /// asks the user about.
  Future<void> addWidget(WidgetKind kind) =>
      HomeWidget.requestPinWidget(androidName: kind.androidName);

  /// How the phone draws widgets, which only the app's own build of the
  /// phone's side knows: as near as the app can tell without it otherwise.
  Future<WidgetLook> look() async {
    try {
      final look = await _channel.invokeMapMethod<Object?, Object?>("look");
      return look == null ? const WidgetLook() : WidgetLook.fromMap(look);
    } catch (e) {
      return const WidgetLook();
    }
  }

  /// The widget a tap on which opened the app, if one did.
  Future<WidgetKind?> launchedFrom() async =>
      _kindOf(await HomeWidget.initiallyLaunchedFromHomeWidget());

  /// The widgets tapped while the app was open already, in the background.
  Stream<WidgetKind> get taps => HomeWidget.widgetClicked
      .map(_kindOf)
      .where((kind) => kind != null)
      .cast<WidgetKind>();

  static WidgetKind? _kindOf(Uri? uri) {
    if (uri == null || uri.scheme != _scheme) return null;
    return switch (uri.host) {
      "tasks" => WidgetKind.tasks,
      "note" => WidgetKind.note,
      _ => null,
    };
  }
}
