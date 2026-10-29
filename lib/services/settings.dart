import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';

class AppSettings extends ChangeNotifier {
  late SharedPreferences _p;

  static const defaultModel = 'gemini-flash-latest';

  ThemeMode themeMode = ThemeMode.system;
  bool onboardingDone = false;
  String apiKey = '';
  String model = defaultModel;

  bool get hasOwnKey => apiKey.trim().isNotEmpty;
  bool get aiReady => hasOwnKey || Env.hasBuiltInKey;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[_p.getInt('themeMode') ?? 0];
    onboardingDone = _p.getBool('onboardingDone') ?? false;
    apiKey = _p.getString('apiKey') ?? '';
    model = _p.getString('model') ?? defaultModel;
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _p.setInt('themeMode', m.index);
    notifyListeners();
  }

  void finishOnboarding() {
    onboardingDone = true;
    _p.setBool('onboardingDone', true);
    notifyListeners();
  }

  void setApiKey(String v) {
    apiKey = v.trim();
    _p.setString('apiKey', apiKey);
    notifyListeners();
  }
}
