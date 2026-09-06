import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createPlatformMqttClient({
  required String host,
  required String clientId,
  required int port,
  required bool secure,
  String path = '/mqtt',
}) {
  final scheme = secure ? 'wss' : 'ws';
  final cleanHost = host
      .replaceFirst(RegExp(r'^[a-zA-Z0-9+-]+://'), '')
      .split('/')
      .first
      .split(':')
      .first;

  final normalizedPath = path.isEmpty
      ? ''
      : (path.startsWith('/') ? path : '/$path');

  final serverUri = '$scheme://$cleanHost$normalizedPath';

  final client = MqttBrowserClient.withPort(serverUri, clientId, port);
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
