import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../models/user_profile.dart';
import '../models/widget_look.dart';
import '../models/widget_style.dart';
import '../services/home_widget_service.dart';

/// The app's widgets on the home screen, as the settings show them: how
/// each looks, and how the phone draws them, for the previews of their
/// styles; and adding one. And the page a tap on one has the app show.
class WidgetsViewModel with ChangeNotifier {
  /// [launchedFrom] is the widget a tap on which opened the app, if one did.
  WidgetsViewModel({HomeWidgetService? service, WidgetKind? launchedFrom})
    : _service = service ?? HomeWidgetService(),
      launchPage = launchedFrom == null ? null : pageFor(launchedFrom) {
    _taps = _service.taps.listen(
      (kind) => _pageRequests.add(pageFor(kind)),
      // A widget's trouble, which the app carries on without.
      onError: (Object e) {},
    );
  }

  final HomeWidgetService _service;
  late final StreamSubscription<WidgetKind> _taps;
  final _pageRequests = StreamController<StartPage>.broadcast();

  @override
  void dispose() {
    _taps.cancel();
    _pageRequests.close();
    super.dispose();
  }

  /// The page a tap on [kind] of widget opens: its own.
  static StartPage pageFor(WidgetKind kind) => switch (kind) {
    WidgetKind.tasks => StartPage.tasks,
    WidgetKind.note => StartPage.notes,
  };

  /// The page a tap on a widget opened the app on, which it opens on in
  /// place of the start page.
  final StartPage? launchPage;

  /// The pages taps on the widgets ask for while the app is open already.
  Stream<StartPage> get pageRequests => _pageRequests.stream;

  final _styles = <WidgetKind, WidgetStyle>{};

  /// How [kind] of widget looks, once [load] has read it in.
  WidgetStyle styleOf(WidgetKind kind) =>
      _styles[kind] ?? WidgetStyle.defaultFor(kind);

  /// How the phone draws widgets, once [load] has asked it.
  WidgetLook get look => _look;
  WidgetLook _look = const WidgetLook();

  /// Whether the app can add a widget to the home screen, which the phone
  /// asks the user about.
  bool get canAdd => _canAdd;
  bool _canAdd = false;

  /// The text the note widget shows, or null when it shows no note.
  String? get noteText => _noteText;
  String? _noteText;

  /// Reads in how the widgets look, how the phone draws them and how big
  /// they are, and what the note widget shows: afresh each time, as the
  /// home screen can change while the app's away.
  Future<void> load() async {
    for (final kind in WidgetKind.values) {
      try {
        _styles[kind] = await _service.styleOf(kind);
      } catch (e) {
        // As it first comes, then, as the widget takes it too.
      }
    }
    _look = await _service.look();
    try {
      _canAdd = await _service.canAddWidget();
    } catch (e) {
      _canAdd = false;
    }
    _noteText = await _shownNoteText();
    notifyListeners();
  }

  /// Reads in afresh what the note widget shows, as a note may have been put
  /// on it from its editor since.
  Future<void> loadNote() async {
    final text = await _shownNoteText();
    if (text == _noteText) return;
    _noteText = text;
    notifyListeners();
  }

  /// Takes the note off the note widget, which goes back to saying "Note"
  /// until another is put on it from its editor.
  Future<Result> clearNote() async {
    try {
      await _service.clearNote();
    } catch (e) {
      return const Failure("Couldn't clear the widget");
    }
    _noteText = null;
    notifyListeners();
    return const Success("Widget Cleared");
  }

  /// The text the note widget shows, or null when it shows no note, or that
  /// can't be told.
  Future<String?> _shownNoteText() async {
    try {
      return (await _service.shownNote()).text;
    } catch (e) {
      return null;
    }
  }

  /// Has every widget of [kind] look as [style] has it.
  Future<Result> setStyle(WidgetKind kind, WidgetStyle style) async {
    try {
      await _service.setStyle(kind, style);
    } catch (e) {
      return const Failure("Couldn't change the widget");
    }
    _styles[kind] = style;
    notifyListeners();
    return const Success("Widget Updated");
  }

  /// Asks the phone to add [kind] of widget to the home screen. Null once
  /// it's asked the user, who says for themselves.
  Future<Result?> add(WidgetKind kind) async {
    try {
      await _service.addWidget(kind);
      return null;
    } catch (e) {
      return const Failure("Couldn't add the widget");
    }
  }
}
