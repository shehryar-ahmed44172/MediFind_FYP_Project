import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per account, whether the welcome walkthrough has been shown.
/// Namespaced by user id so two accounts on one phone each see it once.
class GuidePrefs {
  static String _key(String userId) => 'guide_${userId}_seen';

  static Future<bool> hasSeen(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(userId)) ?? false;
    } catch (_) {
      // A failing preference store must never block the app.
      return true;
    }
  }

  static Future<void> markSeen(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId), true);
    } catch (_) {
      // ignored — the walkthrough may then show again next time
    }
  }
}
