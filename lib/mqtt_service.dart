import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'settings_service.dart';
import 'notification_service.dart';
import 'db_service.dart';

// Умовні імпорти для кросплатформності (щоб працювало і на Web, і на Android)
import 'mqtt_setup.dart'
    if (dart.library.io) 'mqtt_setup_io.dart'
    if (dart.library.html) 'mqtt_setup_web.dart';

enum MqttConnectionState { connected, disconnected, connecting, error }

class MqttService {
  late MqttClient client;
  final settings = SettingsService();
  final _notifications = NotificationService();

  final _tempStream = StreamController<String>.broadcast();
  final _humStream = StreamController<String>.broadcast();
  final _stateStream = StreamController<MqttConnectionState>.broadcast();

  final _dbService = DbService();

  // --- Змінні для таймера тиші тривог (5 хвилин) ---
  DateTime? _lastTempAlert;
  DateTime? _lastHumAlert;

  // --- Змінні для фільтрації запису в БД (1 хвилина) ---
  DateTime? _lastTempDbSave;
  DateTime? _lastHumDbSave;

  Stream<String> get tempStream => _tempStream.stream;
  Stream<String> get humStream => _humStream.stream;
  Stream<MqttConnectionState> get stateStream => _stateStream.stream;

  Future<void> connect() async {
    _stateStream.add(MqttConnectionState.connecting);
    await settings.load();
    await _notifications.init();

    final String clientId = 'roman_iot_${DateTime.now().millisecondsSinceEpoch}';
    
    // Використовуємо функцію з умовних імпортів
    client = setupMqttClient(clientId);
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;

    try {
      await client.connect();
      _stateStream.add(MqttConnectionState.connected);
      client.subscribe('roman_41ki/temp', MqttQos.atMostOnce);
      client.subscribe('roman_41ki/hum', MqttQos.atMostOnce);

      client.updates!.listen((c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        _processData(c[0].topic, pt);
      });
    } catch (e) {
      _stateStream.add(MqttConnectionState.error);
    }
  }

  // ВІДНОВЛЕНИЙ ПОЧАТОК ФУНКЦІЇ:
  void _processData(String topic, String payload) {
    double? val = double.tryParse(payload);
    if (val == null) return;

    String type = topic.contains('temp') ? 'temp' : 'hum';
    DateTime now = DateTime.now();

    // 1. РОЗДІЛЕННЯ: Оновлення UI в реальному часі (Миттєво)
    if (type == 'temp') {
      _tempStream.add(payload); // Відправляємо на головний екран
      
      // ЗБЕРЕЖЕННЯ: Перевіряємо, чи змінилася поточна хвилина порівняно з останнім записом
      if (_lastTempDbSave == null || _lastTempDbSave!.minute != now.minute) {
        _dbService.insertLog(type, val);
        _lastTempDbSave = now; // Запам'ятовуємо час цього запису
      }
    } else {
      _humStream.add(payload); // Відправляємо на головний екран
      
      // ЗБЕРЕЖЕННЯ: Перевіряємо, чи змінилася поточна хвилина порівняно з останнім записом
      if (_lastHumDbSave == null || _lastHumDbSave!.minute != now.minute) {
        _dbService.insertLog(type, val);
        _lastHumDbSave = now; // Запам'ятовуємо час цього запису
      }
    }

    // 2. ЛОГІКА ТРИВОГ (Push-сповіщення з інтервалом 5 хв)
    String? alarmMsg = settings.checkAlarm(val, type);

    if (alarmMsg != null) {
      if (type == 'temp') {
        if (_lastTempAlert == null || now.difference(_lastTempAlert!).inMinutes >= 5) {
          _notifications.show("УВАГА: ТЕМПЕРАТУРА", alarmMsg);
          _lastTempAlert = now;
        }
      } else if (type == 'hum') {
        if (_lastHumAlert == null || now.difference(_lastHumAlert!).inMinutes >= 5) {
          _notifications.show("УВАГА: ВОЛОГІСТЬ", alarmMsg);
          _lastHumAlert = now;
        }
      }
    } else {
      // Скидаємо таймер тривоги, якщо все повернулося в норму
      if (type == 'temp') _lastTempAlert = null;
      if (type == 'hum') _lastHumAlert = null;
    }
  }

  void dispose() {
    _tempStream.close(); 
    _humStream.close(); 
    _stateStream.close();
    client.disconnect();
  }
}