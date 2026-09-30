import 'package:shared_preferences/shared_preferences.dart';

enum AppLocale { en, tr, es, de, fr }

class LocaleStorage {
  LocaleStorage._();

  static const _key = 'app_locale';
  static SharedPreferences? _prefs;
  static AppLocale _locale = AppLocale.en;

  static AppLocale get locale => _locale;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    _locale = AppLocale.values.firstWhere(
      (l) => l.name == raw,
      orElse: () => AppLocale.en,
    );
  }

  static Future<void> setLocale(AppLocale locale) async {
    _locale = locale;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_key, locale.name);
  }
}
