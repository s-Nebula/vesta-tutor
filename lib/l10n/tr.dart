import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'en.dart';

/// UI language. Spanish text is the key; English comes from [enStrings].
/// 'system' follows the phone: Spanish on Spanish phones, English otherwise.
class LanguageNotifier extends ChangeNotifier {
  static const _key = 'app_language';
  static const choices = ['system', 'es', 'en'];

  /// Reads the saved choice. Call before runApp so the first frame is right.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && choices.contains(saved)) _choice = saved;
    } catch (_) {
      // No storage: follow the phone.
    }
  }

  String get choice => _choice;

  void setChoice(String value) {
    if (!choices.contains(value) || value == _choice) return;
    _choice = value;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_key, value))
        .ignore();
  }
}

String _choice = 'system';

/// Forces a language in tests ('system', 'es' or 'en').
@visibleForTesting
void debugSetAppLanguage(String choice) => _choice = choice;

/// Language actually in use: 'es' or 'en'.
String get appLanguage {
  if (_choice != 'system') return _choice;
  return PlatformDispatcher.instance.locale.languageCode == 'es' ? 'es' : 'en';
}

bool get isEnglish => appLanguage == 'en';

/// Translates a Spanish UI string. Placeholders {0}, {1}... take [args].
String tr(String es, [List<Object?> args = const []]) {
  var text = isEnglish ? (enStrings[es] ?? es) : es;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i]}');
  }
  return text;
}
