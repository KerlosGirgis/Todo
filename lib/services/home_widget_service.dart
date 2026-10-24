import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The note widget on the home screen: what it shows, and how.
class HomeWidgetService {
  Future<void> showNote(String note) async {
    await HomeWidget.saveWidgetData("note", note);
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
