import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { turkish, english, german }

class AppLanguageController extends ValueNotifier<AppLanguage> {
  AppLanguageController() : super(AppLanguage.turkish);

  static const _storageKey = 'app.language';

  bool get isEnglish => value == AppLanguage.english;
  bool get isGerman => value == AppLanguage.german;

  Future<void> load() async {
    try {
      final saved = await SharedPreferencesAsync().getString(_storageKey);
      value = switch (saved) {
        'en' => AppLanguage.english,
        'de' => AppLanguage.german,
        _ => AppLanguage.turkish,
      };
    } catch (_) {
      value = AppLanguage.turkish;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (value != language) value = language;
    try {
      await SharedPreferencesAsync().setString(_storageKey, switch (language) {
        AppLanguage.english => 'en',
        AppLanguage.german => 'de',
        AppLanguage.turkish => 'tr',
      });
    } catch (_) {
      // Depolama kullanılamasa da seçim mevcut oturumda çalışır.
    }
  }
}

final appLanguage = AppLanguageController();

const _germanTexts = <String, String>{
  'PLAY NOW': 'JETZT SPIELEN',
  'GAME MODES': 'SPIELMODI',
  'SELECT TABLE': 'TISCH WÄHLEN',
  'TOURNAMENTS': 'TURNIERE',
  'MISSIONS': 'AUFGABEN',
  'SETTINGS': 'EINSTELLUNGEN',
  'SAVE': 'SPEICHERN',
  'Sound Effects': 'Soundeffekte',
  'NOTIFICATIONS': 'BENACHRICHTIGUNGEN',
  'VIBRATION': 'VIBRATION',
  'OPPONENT PICTURES': 'GEGNERBILDER',
  'AUTO ARRANGE RACK': 'ABLAGE AUTOMATISCH SORTIEREN',
  'LANGUAGE': 'SPRACHE',
  'Text Size': 'Textgröße',
  'Small': 'Klein',
  'Large': 'Groß',
  'Normal': 'Normal',
  'Daily Reward': 'Tägliche Belohnung',
  'Wallet is under construction.': 'Die Brieftasche ist in Arbeit.',
};

String localizedText(
  AppLanguage language,
  String turkish,
  String english, {
  String? german,
}) => switch (language) {
  AppLanguage.turkish => turkish,
  AppLanguage.english => english,
  AppLanguage.german => german ?? _germanTexts[english] ?? english,
};

String appText(String turkish, String english, {String? german}) =>
    localizedText(appLanguage.value, turkish, english, german: german);
