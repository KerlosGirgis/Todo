import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerseService {
  static List<String>? _verses;
  static String installId="";

  // Load and cache verses
  static Future<void> loadVerses() async {
    if (_verses == null) {
      String content = await rootBundle.loadString('assets/nasb.json');
      _verses = List<String>.from(json.decode(content));
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? tempInstallId = prefs.getString('installId');
    if (tempInstallId == null) {
      // Generate a new random install-specific identifier
      tempInstallId = Random().nextInt(1000000).toString();
      await prefs.setString('installId', tempInstallId).then((onValue){
        installId=tempInstallId!;
      });
    }
    else{
      installId=tempInstallId;
    }
  }

  // Get daily verse
  static String getDailyVerse() {
    if (_verses == null || _verses!.isEmpty) {
      throw Exception('Verses not loaded');
    }

    // Use today's date to create a consistent random seed
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int seed = today.hashCode+installId.toString().hashCode;
    Random random = Random(seed);

    // Pick a random verse based on the seed
    int index = random.nextInt(_verses!.length);
    return _verses![index];
  }
}