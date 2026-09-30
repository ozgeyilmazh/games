import 'package:shared_preferences/shared_preferences.dart';

class ScoreStorage {
  ScoreStorage._();

  static const _highScoreKey = 'high_score';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static int loadHighScore() => _prefs?.getInt(_highScoreKey) ?? 0;

  static Future<void> saveHighScore(int value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_highScoreKey, value);
  }
}
