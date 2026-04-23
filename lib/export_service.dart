import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// ДОДАНО: імпорт debugPrint
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class ExportService {
  /// Експортує переданий список логів у CSV файл та відкриває меню "Поділитися"
  static Future<void> exportLogsToCSV(List<Map<String, dynamic>> logs) async {
    // 1. Перевірка платформи (на Web файлова система працює інакше, 
    // тому для початку реалізуємо логіку тільки для мобільних пристроїв)
    if (kIsWeb) {
      // ВИПРАВЛЕНО: Використовуємо debugPrint замість print
      debugPrint("Експорт у файл на Web потребує іншого підходу (завантаження файлу).");
      return;
    }

    if (logs.isEmpty) return;

    // 2. Формування даних для CSV (додаємо заголовки колонок)
    List<List<dynamic>> csvData = [
      ['ID', 'Дата та Час', 'Тип вимірювання', 'Значення']
    ];

    // Наповнення рядків даними з БД
    for (var log in logs) {
      String typeName = log['type'] == 'temp' ? 'Температура (°C)' : 'Вологість (%)';
      csvData.add([
        log['id'] ?? '-', 
        log['timestamp'], 
        typeName, 
        log['value']
      ]);
    }

    // 3. Генерація CSV рядка
    // Використовуємо стандартний розділювач коми
    String csvContent = const ListToCsvConverter().convert(csvData);

    try {
      // 4. Отримання доступу до тимчасової директорії пристрою
      final directory = await getTemporaryDirectory();
      
      // Формування унікального імені файлу з поточною датою
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final path = '${directory.path}/iot_telemetry_$timestamp.csv';
      
      // Збереження файлу
      final file = File(path);
      await file.writeAsString(csvContent);

      // 5. Передача файлу через зовнішні застосунки (Share)
      await Share.shareXFiles(
        [XFile(path)], 
        text: 'Аналітична звітність: телеметрія IoT',
      );
    } catch (e) {
      // ВИПРАВЛЕНО: Використовуємо debugPrint замість print
      debugPrint("Помилка під час експорту: $e");
    }
  }
}