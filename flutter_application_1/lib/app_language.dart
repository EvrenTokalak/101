import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { turkish, english }

class AppLanguageController extends ValueNotifier<AppLanguage> {
  AppLanguageController() : super(AppLanguage.turkish);

  static const _storageKey = 'app.language';

  bool get isEnglish => value == AppLanguage.english;

  Future<void> load() async {
    try {
      final saved = await SharedPreferencesAsync().getString(_storageKey);
      value = saved == 'en' ? AppLanguage.english : AppLanguage.turkish;
    } catch (_) {
      value = AppLanguage.turkish;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (value != language) value = language;
    try {
      await SharedPreferencesAsync().setString(
        _storageKey,
        language == AppLanguage.english ? 'en' : 'tr',
      );
    } catch (_) {
      // Depolama kullanılamasa da seçim mevcut oturumda çalışır.
    }
  }
}

final appLanguage = AppLanguageController();

String appText(String turkish, String english) =>
    appLanguage.isEnglish ? english : turkish;
