import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  double tempMin = 20.0, tempMax = 20.0;
  double humMin = 20.0, humMax = 20.0;
  bool isDark = true; // Default to dark mode for premium glassmorphism

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    tempMin = prefs.getDouble('tempMin') ?? 20.0;
    tempMax = prefs.getDouble('tempMax') ?? 20.0;
    humMin = prefs.getDouble('humMin') ?? 20.0;
    humMax = prefs.getDouble('humMax') ?? 20.0;
    isDark = prefs.getBool('isDark') ?? true;
  }

  Future<void> update(double tMin, double tMax, double hMin, double hMax) async {
    tempMin = tMin; tempMax = tMax; humMin = hMin; humMax = hMax;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tempMin', tMin);
    await prefs.setDouble('tempMax', tMax);
    await prefs.setDouble('humMin', hMin);
    await prefs.setDouble('humMax', hMax);
  }

  Future<void> setDarkMode(bool value) async {
    isDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', value);
  }

  String? checkAlarm(double val, String type) {
    if (type == 'temp') {
      if (val < tempMin) return "Температура занизька: $val°C";
      if (val > tempMax) return "Температура зависока: $val°C";
    } else if (type == 'hum') {
      if (val < humMin) return "Вологість занизька: $val%";
      if (val > humMax) return "Вологість зависока: $val%";
    }
    return null;
  }
}
