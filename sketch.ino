#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

#define DHTPIN 15
#define DHTTYPE DHT22
#define STATUS_TOPIC "roman_41ki/status"

DHT dht(DHTPIN, DHTTYPE);
WiFiClient espClient;
PubSubClient client(espClient);

const char* ssid = "Wokwi-GUEST";
const char* mqtt_server = "broker.emqx.io";

void setup() {
  Serial.begin(115200);
  dht.begin();
  setup_wifi();
  client.setServer(mqtt_server, 1883);
}

void setup_wifi() {
  WiFi.begin(ssid, "");
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("\nWiFi connected");
}

void reconnect() {
  while (!client.connected()) {
    String clientId = "ESP32_Roman_" + String(random(0, 0xffff), HEX);
    // Налаштування Last Will: якщо клієнт зникне, брокер відправить "offline"
    if (client.connect(clientId.c_str(), STATUS_TOPIC, 1, true, "offline")) {
      client.publish(STATUS_TOPIC, "online", true);
      Serial.println("MQTT Connected");
    } else {
      delay(5000);
    }
  }
}

void loop() {
  if (!client.connected()) reconnect();
  client.loop();

  static unsigned long lastMsg = 0;
  if (millis() - lastMsg > 5000) {
    lastMsg = millis();
    float h = dht.readHumidity();
    float t = dht.readTemperature();

    if (!isnan(h) && !isnan(t)) {
      client.publish("roman_41ki/temp", String(t, 1).c_str());
      client.publish("roman_41ki/hum", String(h, 1).c_str());
    }
  }
}