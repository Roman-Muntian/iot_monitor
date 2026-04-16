import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'settings_service.dart';
import 'notification_service.dart';
import 'db_service.dart';

enum MqttConnectionState { connected, disconnected, connecting, error }

class MqttService {
  late MqttClient client;
  final settings = SettingsService();
  final _notifications = NotificationService();

  final _tempStream = StreamController<String>.broadcast();
  final _humStream = StreamController<String>.broadcast();
  final _alertStream = StreamController<String>.broadcast();
  final _stateStream = StreamController<MqttConnectionState>.broadcast();

  final _dbService = DbService();

  Stream<String> get tempStream => _tempStream.stream;
  Stream<String> get humStream => _humStream.stream;
  Stream<String> get alertStream => _alertStream.stream;
  Stream<MqttConnectionState> get stateStream => _stateStream.stream;

  Future<void> connect() async {
    _stateStream.add(MqttConnectionState.connecting);
    await settings.load();
    await _notifications.init();

    final String clientId = 'roman_iot_${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      client = MqttBrowserClient('ws://broker.emqx.io/mqtt', clientId)..port = 8083;
    } else {
      client = MqttServerClient('broker.emqx.io', clientId)..port = 1883;
    }

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

  void _processData(String topic, String payload) {
    double? val = double.tryParse(payload);
    if (val == null) return;

    String type = topic.contains('temp') ? 'temp' : 'hum';
    
    if (type == 'temp') {
      _tempStream.add(payload);
    } else {
      _humStream.add(payload);
    }

    // Зберігаємо дані в локальну БД
    _dbService.insertLog(type, val);

    String? alarm = settings.checkAlarm(val, type);
    if (alarm != null) {
      _alertStream.add(alarm);
      _notifications.show("УВАГА: IoT ТРИВОГА", alarm);
    }
  }

  void dispose() {
    _tempStream.close(); 
    _humStream.close(); 
    _alertStream.close(); 
    _stateStream.close();
    client.disconnect();
  }
}