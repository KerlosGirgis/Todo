import 'package:shared_preferences/shared_preferences.dart';

/// Which version of each page's tour the user has been through, kept with
/// the app's other settings on the phone.
class TourService {
  static String _key(String tour) => 'tour.$tour';

  /// The version of [tour] the user last went through, or 0 for none.
  Future<int> seenVersion(String tour) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(tour)) ?? 0;
  }

  Future<void> setSeenVersion(String tour, int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(tour), version);
  }
}
