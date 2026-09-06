import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createPlatformMqttClient({
  required String host,
  required String clientId,
  required int port,
  required bool secure,
  String path = '/mqtt',
}) {
  final cleanHost = host
      .replaceFirst(RegExp(r'^[a-zA-Z0-9+-]+://'), '')
      .split('/')
      .first
      .split(':')
      .first;

  final client = MqttServerClient.withPort(cleanHost, clientId, port);
  if (secure) {
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
  }
  return client;
}
