import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient setupMqttClient(String clientId) {
  return MqttBrowserClient('ws://broker.emqx.io/mqtt', clientId)..port = 8083;
}