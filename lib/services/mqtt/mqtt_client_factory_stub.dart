import 'package:mqtt_client/mqtt_client.dart';

MqttClient createPlatformMqttClient({
  required String host,
  required String clientId,
  required int port,
  required bool secure,
  String path = '/mqtt',
}) {
  throw UnsupportedError(
    'MQTT client is not supported on this platform without dart:io or dart:js_interop.',
  );
}
