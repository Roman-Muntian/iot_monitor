import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Додано для перевірки платформи

class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  Database? _db;

  // Тимчасовий список для зберігання даних, коли ми тестуємо у браузері (Web)
  final List<Map<String, dynamic>> _webMemoryDb = [];

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // Якщо це Web, ми навіть не намагаємося ініціалізувати SQLite, щоб уникнути крашу
    if (kIsWeb) return _db!; 

    String path = join(await getDatabasesPath(), 'iot_telemetry.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            type TEXT,
            value REAL
          )
        ''');
      },
    );
  }

Future<void> insertLog(String type, double value) async {
    // Отримуємо поточний час
    final now = DateTime.now();
    
    // Створюємо новий об'єкт часу, примусово встановлюючи секунди і мілісекунди в 0
    final cleanTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    
    // Результат буде у форматі: 2024-05-20T14:30:00
    final cleanTimestamp = cleanTime.toIso8601String().split('.').first;

    // ЛОГІКА ДЛЯ БРАУЗЕРА
    if (kIsWeb) {
      _webMemoryDb.insert(0, {
        'timestamp': cleanTimestamp,
        'type': type,
        'value': value
      });
      if (_webMemoryDb.length > 1000) _webMemoryDb.removeLast(); 
      return;
    }

    // ЛОГІКА ДЛЯ ANDROID / iOS
    final database = await db;
    await database.insert('logs', {
      'timestamp': cleanTimestamp,
      'type': type,
      'value': value
    });
    
    await database.execute('''
      DELETE FROM logs WHERE id NOT IN (
        SELECT id FROM logs ORDER BY id DESC LIMIT 1000
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getLogs({String? type, String? date}) async {
    // ЛОГІКА ДЛЯ БРАУЗЕРА
    if (kIsWeb) {
      return _webMemoryDb.where((log) {
        bool matchesType = (type == null || type == 'Всі') || (log['type'] == (type == 'Температура' ? 'temp' : 'hum'));
        bool matchesDate = (date == null || date.isEmpty) || (log['timestamp'].toString().startsWith(date));
        return matchesType && matchesDate;
      }).toList();
    }

    // ЛОГІКА ДЛЯ ANDROID / iOS
    final database = await db;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (type != null && type != 'Всі') {
      where += ' AND type = ?';
      whereArgs.add(type == 'Температура' ? 'temp' : 'hum');
    }
    
    if (date != null && date.isNotEmpty) {
      where += ' AND timestamp LIKE ?';
      whereArgs.add('$date%');
    }

    final result = await database.query('logs', where: where, whereArgs: whereArgs, orderBy: 'timestamp DESC');
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> clearLogs() async {
    // ЛОГІКА ДЛЯ БРАУЗЕРА
    if (kIsWeb) {
      _webMemoryDb.clear();
      return;
    }

    // ЛОГІКА ДЛЯ ANDROID / iOS
    final database = await db;
    await database.delete('logs');
  }
}