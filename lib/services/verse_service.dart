import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The verses of the day, from the Bible bundled with the app.
class VerseService {
  // Loaded once for every instance.
  static List<String>? _verses;
  static String _installId = "";

  /// Reads in the verses, the first time, and the app's own id on this
  /// phone, which a new install makes up: the verse of the day goes by it,
  /// so that it isn't the same one on every phone.
  Future<void> loadVerses() async {
    if (_verses == null) {
      final content = await rootBundle.loadString('assets/nasb.json');
      _verses = await Isolate.run(
        () => List<String>.from(json.decode(content)),
      );
    }
    final prefs = await SharedPreferences.getInstance();
    var installId = prefs.getString('installId');
    if (installId == null) {
      installId = Random.secure().nextInt(1000000).toString();
      await prefs.setString('installId', installId);
    }
    _installId = installId;
  }

  /// Today's verse: the same all day, picked by the date and the app's id.
  String getDailyVerse() {
    final verses = _verses;
    if (verses == null || verses.isEmpty) {
      throw Exception('Verses not loaded');
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final random = Random(today.hashCode + _installId.hashCode);
    return verses[random.nextInt(verses.length)];
  }
}
