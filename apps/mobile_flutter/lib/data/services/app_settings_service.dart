import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_settings_keys.dart';

class AppSettingsService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<bool> isPushNotificationsEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(AppSettingsKeys.pushNotificationsEnabled) ?? true;
  }

  Future<void> setPushNotificationsEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(AppSettingsKeys.pushNotificationsEnabled, enabled);
  }
}


