import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true, 
      requestBadgePermission: true, 
      requestSoundPermission: true
    );
    
    // ПРАВИЛЬНО: iOS з великих літер
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iosSettings),
    );
  }

  Future<void> show(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'iot_alerts', 'IoT Monitoring', 
        importance: Importance.max, 
        priority: Priority.high
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(DateTime.now().millisecond, title, body, details);
  }
}