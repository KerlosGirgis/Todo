import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The note widget on the home screen: what it shows, and how.
class HomeWidgetService {
  /// Shows [text], the text of the note with [noteId], on the widget.
  Future<void> showNote(int noteId, String text) async {
    await HomeWidget.saveWidgetData<int>("noteId", noteId);
    await HomeWidget.saveWidgetData<String>("note", text);
    await HomeWidget.updateWidget(androidName: "Note");
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
    await HomeWidget.updateWidget(androidName: "Note");
  }

  Future<void> setCasualFont(bool useCasual) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCasualFont', useCasual);
    // Update the home widget after changing the font preference
    await HomeWidget.saveWidgetData('useCasualFont', useCasual);
    await HomeWidget.updateWidget(name: 'Note');
  }

  /// [size] is a multiple of the widget's default text size.
  Future<void> setTextSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widgetTextSize', size.toStringAsFixed(2));
    await HomeWidget.saveWidgetData('widgetTextSize', size.toStringAsFixed(2));
    await HomeWidget.updateWidget(name: 'Note');
  }
}
