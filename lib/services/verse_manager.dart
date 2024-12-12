import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

class VerseManager {
  static List<String>? _verses;

  // Load and cache verses
  static Future<void> loadVerses() async {
    if (_verses == null) {
      String content = await rootBundle.loadString('assets/nasb.json');
      _verses = List<String>.from(json.decode(content));
    }
  }

  // Get daily verse
  static String getDailyVerse() {
    if (_verses == null || _verses!.isEmpty) {
      throw Exception('Verses not loaded');
    }

    // Use today's date to create a consistent random seed
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int seed = today.hashCode;
    Random random = Random(seed);

    // Pick a random verse based on the seed
    int index = random.nextInt(_verses!.length);
    return _verses![index];
  }
}