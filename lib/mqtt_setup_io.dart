import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient setupMqttClient(String clientId) {
  return MqttServerClient('broker.emqx.io', clientId)..port = 1883;
}