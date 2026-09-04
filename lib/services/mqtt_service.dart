import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../core/constants/app_config.dart';
import '../models/encrypted_packet.dart';
import 'crypto_service.dart';

/// Manages real-time MQTT connectivity and encrypted message distribution.
class MqttService {
  final CryptoService cryptoService;
  MqttServerClient? _client;

  String? _roomId;
  String? _myId;
  String? _topicPrefix;
  String? _myTopic;
  String? _roomWildcardTopic;

  final StreamController<Map<String, dynamic>> _incomingMessagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingMessages => _incomingMessagesController.stream;

  String? get roomId => _roomId;
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  MqttService({required this.cryptoService});

  /// Connects to MQTT broker and subscribes to room wildcard topic
  Future<bool> connect({
    required String roomId,
    required String myId,
    String? brokerHost,
    int? port,
  }) async {
    _roomId = roomId;
    _myId = myId;
    _topicPrefix = '${AppConfig.topicPrefix}/$roomId';
    _myTopic = '$_topicPrefix/$myId';
    _roomWildcardTopic = '$_topicPrefix/+';

    final host = brokerHost ?? AppConfig.mqttBrokerHost;
    final brokerPort = port ?? AppConfig.mqttTcpPort;

    _client = MqttServerClient.withPort(host, myId, brokerPort);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    _client!.autoReconnect = true;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onAutoReconnected = _onAutoReconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(myId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      _client?.disconnect();
      return false;
    }

    if (isConnected) {
      _subscribeToRoom();
      return true;
    }
    return false;
  }

  void _subscribeToRoom() {
    if (_roomWildcardTopic != null && isConnected) {
      _client!.subscribe(_roomWildcardTopic!, MqttQos.atMostOnce);
      _client!.updates?.listen(_handleIncomingMqttMessage);
    }
  }

  void _onConnected() {
    _subscribeToRoom();
  }

  void _onAutoReconnected() {
    _subscribeToRoom();
  }

  void _onDisconnected() {}

  /// Handles incoming MQTT packet, decrypts E2EE payload, and emits to stream
  Future<void> _handleIncomingMqttMessage(
      List<MqttReceivedMessage<MqttMessage?>>? events) async {
    if (events == null || events.isEmpty) return;

    for (final event in events) {
      final recMess = event.payload as MqttPublishMessage;
      final payloadString =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      try {
        final Map<String, dynamic> rawJson = jsonDecode(payloadString);
        final encryptedPacket = EncryptedPacket.fromJson(rawJson);
        final decryptedData = await cryptoService.decryptPayload(encryptedPacket);

        if (decryptedData != null) {
          // Ignore own messages
          if (decryptedData['id'] != _myId) {
            _incomingMessagesController.add(decryptedData);
          }
        }
      } catch (e) {
        // Ignored or invalid packet
      }
    }
  }

  /// Encrypts and publishes a message object to the user's personal room topic
  Future<bool> broadcast(Map<String, dynamic> data) async {
    if (!isConnected || _myTopic == null || !cryptoService.hasKey) {
      return false;
    }

    try {
      final encryptedPacket = await cryptoService.encryptPayload(data);
      if (encryptedPacket == null) return false;

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(encryptedPacket.toJson()));

      _client!.publishMessage(
        _myTopic!,
        MqttQos.atMostOnce,
        builder.payload!,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Disconnects from broker and closes listeners
  void disconnect() {
    try {
      _client?.disconnect();
    } catch (_) {}
  }

  void dispose() {
    disconnect();
    _incomingMessagesController.close();
  }
}
