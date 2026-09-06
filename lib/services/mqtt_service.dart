import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../core/constants/app_config.dart';
import '../models/encrypted_packet.dart';
import 'crypto_service.dart';
import 'mqtt/mqtt_client_factory.dart';

/// Candidate server endpoint configuration for connection attempts
class _MqttCandidate {
  final String host;
  final int port;
  final bool secure;
  final String path;
  final String? username;
  final String? password;

  const _MqttCandidate({
    required this.host,
    required this.port,
    required this.secure,
    this.path = '/mqtt',
    this.username,
    this.password,
  });

  @override
  String toString() =>
      '$host:$port (TLS/WSS: $secure, Path: $path, Auth: ${username != null && username!.isNotEmpty})';
}

/// Manages real-time MQTT connectivity with TLS/WSS encryption and automatic fallbacks.
class MqttService {
  final CryptoService cryptoService;
  MqttClient? _client;
  StreamSubscription? _updatesSubscription;
  VoidCallback? onReconnected;

  String? _roomId;
  String? _myId;
  String? _clientId;
  String? _topicPrefix;
  String? _myTopic;
  String? _roomWildcardTopic;

  String? _activeBroker;
  int? _activePort;
  bool _isSecure = true;
  String? _lastError;

  final StreamController<Map<String, dynamic>> _incomingMessagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingMessages =>
      _incomingMessagesController.stream;

  String? get roomId => _roomId;
  String? get activeBroker => _activeBroker;
  int? get activePort => _activePort;
  bool get isSecure => _isSecure;
  String? get lastError => _lastError;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  MqttService({required this.cryptoService});

  /// Connects to MQTT broker with automatic TLS -> TCP and broker fallback
  Future<bool> connect({
    required String roomId,
    required String myId,
    String? customClientId,
    String? brokerHost,
    int? port,
    bool? useTls,
    String? username,
    String? password,
  }) async {
    _roomId = roomId;
    _myId = myId.trim().isEmpty
        ? 'user-${DateTime.now().millisecondsSinceEpoch % 1000000}'
        : myId.trim();
    _clientId = (customClientId != null && customClientId.trim().isNotEmpty)
        ? customClientId.trim()
        : _myId;
    _topicPrefix = '${AppConfig.topicPrefix}/$roomId';
    _myTopic = '$_topicPrefix/$_myId';
    _roomWildcardTopic = '$_topicPrefix/+';
    _lastError = null;

    disconnect();

    final effectiveUser = (username != null && username.isNotEmpty)
        ? username
        : AppConfig.defaultMqttUsername;
    final effectivePass = (password != null && password.isNotEmpty)
        ? password
        : AppConfig.defaultMqttPassword;

    // Prepare prioritized candidate list
    final List<_MqttCandidate> candidates = [];

    if (kIsWeb) {
      // In web browsers (Chrome, Edge, Firefox, Safari), MQTT must connect via WebSockets (WSS/WS)
      if (brokerHost != null && brokerHost.trim().isNotEmpty) {
        final customHost = brokerHost.trim();
        final isHiveMqCloud = customHost.contains('hivemq.cloud');
        final isEmqx = customHost.contains('emqx.io');
        final defaultWssPort = isEmqx ? 8084 : AppConfig.mqttWssPort;

        if (port != null) {
          // If port was passed as native 8883, map to WSS port (8884/8084) in browser
          final effectivePort =
              (port == AppConfig.mqttTlsPort) ? defaultWssPort : port;
          final tls = useTls ??
              (effectivePort == defaultWssPort ||
                  effectivePort == 8884 ||
                  effectivePort == 8084 ||
                  effectivePort == 443);
          candidates.add(_MqttCandidate(
            host: customHost,
            port: effectivePort,
            secure: tls,
            path: AppConfig.mqttWssPath,
            username: username ?? (isHiveMqCloud ? effectiveUser : null),
            password: password ?? (isHiveMqCloud ? effectivePass : null),
          ));
        } else {
          candidates.add(_MqttCandidate(
            host: customHost,
            port: defaultWssPort,
            secure: true,
            path: AppConfig.mqttWssPath,
            username: username ?? (isHiveMqCloud ? effectiveUser : null),
            password: password ?? (isHiveMqCloud ? effectivePass : null),
          ));
          if (!isHiveMqCloud) {
            candidates.add(_MqttCandidate(
              host: customHost,
              port: isEmqx ? 8083 : 8000,
              secure: false,
              path: AppConfig.mqttWssPath,
              username: username,
              password: password,
            ));
          }
        }
      } else {
        // 1. Primary: Dedicated HiveMQ Cloud in EU with WSS (8884) & Auth
        candidates.add(_MqttCandidate(
          host: AppConfig.mqttBrokerHost,
          port: AppConfig.mqttWssPort,
          secure: true,
          path: AppConfig.mqttWssPath,
          username: effectiveUser,
          password: effectivePass,
        ));
        // 2. Fallback: Public EMQX WSS (8084)
        candidates.add(const _MqttCandidate(
          host: AppConfig.fallbackBrokerHost,
          port: 8084,
          secure: true,
          path: AppConfig.mqttWssPath,
        ));
        // 3. Fallback: Public EMQX WS (8083)
        candidates.add(const _MqttCandidate(
          host: AppConfig.fallbackBrokerHost,
          port: 8083,
          secure: false,
          path: AppConfig.mqttWssPath,
        ));
        // 4. Fallback: Public HiveMQ WSS (8884)
        candidates.add(const _MqttCandidate(
          host: 'broker.hivemq.com',
          port: 8884,
          secure: true,
          path: AppConfig.mqttWssPath,
        ));
      }
    } else {
      // Native platforms (Android, iOS, Windows, macOS, Linux) with TCP / TLS sockets
      if (brokerHost != null && brokerHost.trim().isNotEmpty) {
        final customHost = brokerHost.trim();
        final isHiveMqCloud = customHost.contains('hivemq.cloud');
        if (port != null) {
          final tls = useTls ?? (port == AppConfig.mqttTlsPort);
          candidates.add(_MqttCandidate(
            host: customHost,
            port: port,
            secure: tls,
            username: username ?? (isHiveMqCloud ? effectiveUser : null),
            password: password ?? (isHiveMqCloud ? effectivePass : null),
          ));
        } else {
          candidates.add(_MqttCandidate(
            host: customHost,
            port: AppConfig.mqttTlsPort,
            secure: true,
            username: username ?? (isHiveMqCloud ? effectiveUser : null),
            password: password ?? (isHiveMqCloud ? effectivePass : null),
          ));
          if (!isHiveMqCloud) {
            candidates.add(_MqttCandidate(
              host: customHost,
              port: AppConfig.mqttTcpPort,
              secure: false,
              username: username,
              password: password,
            ));
          }
        }
      } else {
        // 1. Primary: Dedicated HiveMQ Cloud in EU with TLS (8883) & Auth
        candidates.add(_MqttCandidate(
          host: AppConfig.mqttBrokerHost,
          port: AppConfig.mqttTlsPort,
          secure: true,
          username: effectiveUser,
          password: effectivePass,
        ));
        // 2. Fallback: Public EMQX TLS (8883)
        candidates.add(const _MqttCandidate(
          host: AppConfig.fallbackBrokerHost,
          port: AppConfig.mqttTlsPort,
          secure: true,
        ));
        // 3. Fallback: Public EMQX TCP (1883)
        candidates.add(const _MqttCandidate(
          host: AppConfig.fallbackBrokerHost,
          port: AppConfig.mqttTcpPort,
          secure: false,
        ));
        // 4. Fallback: Public HiveMQ TCP (1883)
        candidates.add(const _MqttCandidate(
          host: 'broker.hivemq.com',
          port: AppConfig.mqttTcpPort,
          secure: false,
        ));
      }
    }

    String accumulatedErrors = '';

    for (final candidate in candidates) {
      debugPrint('🛰️ [MQTT] Tentativo di connessione a $candidate...');
      final success = await _tryConnectCandidate(candidate);
      if (success) {
        debugPrint('✅ [MQTT] Connesso con successo a $candidate');
        _subscribeToRoom();
        return true;
      } else {
        debugPrint('⚠️ [MQTT] Fallito $candidate: $_lastError');
        accumulatedErrors +=
            '${candidate.host}:${candidate.port} ($_lastError); ';
      }
    }

    _lastError = accumulatedErrors.trim();
    return false;
  }

  Future<bool> _tryConnectCandidate(_MqttCandidate candidate) async {
    MqttClient? testClient;
    final effectiveClientId = _clientId ?? _myId!;
    try {
      testClient = MqttClientFactory.createClient(
        host: candidate.host,
        clientId: effectiveClientId,
        port: candidate.port,
        secure: candidate.secure,
        path: candidate.path,
      );
      testClient.logging(on: false);
      testClient.keepAlivePeriod = 20;
      testClient.autoReconnect = true;
      testClient.onDisconnected = _onDisconnected;
      testClient.onConnected = _onConnected;
      testClient.onAutoReconnected = _onAutoReconnected;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(effectiveClientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      if (candidate.username != null && candidate.username!.isNotEmpty) {
        connMessage.authenticateAs(
          candidate.username!,
          candidate.password ?? '',
        );
      }

      testClient.connectionMessage = connMessage;

      final status =
          await testClient.connect().timeout(const Duration(seconds: 8));

      if (status != null && status.state == MqttConnectionState.connected) {
        _client = testClient;
        _activeBroker = candidate.host;
        _activePort = candidate.port;
        _isSecure = candidate.secure;
        _lastError = null;
        return true;
      } else {
        _lastError = status?.returnCode.toString() ?? 'Stato sconosciuto';
        testClient.disconnect();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      testClient?.disconnect();
      return false;
    }
  }

  void _subscribeToRoom() {
    if (_roomWildcardTopic != null && isConnected) {
      _client!.subscribe(_roomWildcardTopic!, MqttQos.atMostOnce);
      _updatesSubscription?.cancel();
      _updatesSubscription =
          _client!.updates?.listen(_handleIncomingMqttMessage);
    }
  }

  void _onConnected() {
    _subscribeToRoom();
    onReconnected?.call();
  }

  void _onAutoReconnected() {
    _subscribeToRoom();
    onReconnected?.call();
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
        final decryptedData =
            await cryptoService.decryptPayload(encryptedPacket);

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
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  void dispose() {
    disconnect();
    _incomingMessagesController.close();
  }
}
