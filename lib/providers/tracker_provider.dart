import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/utils/room_slug.dart';
import '../models/location_point.dart';
import '../models/peer_user.dart';
import '../services/background_service.dart';
import '../services/crypto_service.dart';
import '../services/feedback_service.dart';
import '../services/location_service.dart';
import '../services/mqtt_service.dart';

/// Central state manager orchestrating location tracking, cryptography, and peer networking
class TrackerProvider extends ChangeNotifier {
  final CryptoService cryptoService = CryptoService();
  late final MqttService mqttService;
  final LocationService locationService = LocationService();

  // User Identity (initialized synchronously to prevent empty ID race condition)
  String _myId = 'user-${Random().nextInt(999999).toString().padLeft(6, '0')}';
  String _myName = 'Utente';
  Color _myColor = AppColors.userPalette.first;

  // Room State
  String _groupDisplayName = 'Volantini X';
  String _roomId = 'volantini-x';
  String _roomPassword = '';
  String _cartoKey = '';
  String _brokerHost = AppConfig.mqttBrokerHost;
  String _brokerUsername = AppConfig.defaultMqttUsername;
  String _brokerPassword = AppConfig.defaultMqttPassword;

  // Tracking State
  bool _isTracking = true;
  bool _isInRoom = false;
  LocationPoint? _currentLocation;
  final List<LocationPoint> _myTrail = [];
  final Map<String, PeerUser> _peers = {};

  Timer? _peerCleanupTimer;
  Timer? _heartbeatTimer;

  // Getters
  String get myId => _myId;
  String get myName => _myName;
  Color get myColor => _myColor;
  String get groupDisplayName => _groupDisplayName;
  String get roomId => _roomId;
  String get roomPassword => _roomPassword;
  String get cartoKey => _cartoKey;
  String get brokerHost => _brokerHost;
  String get brokerUsername => _brokerUsername;
  String get brokerPassword => _brokerPassword;
  String? get lastError => mqttService.lastError;
  String? get activeBroker => mqttService.activeBroker;
  bool get isTracking => _isTracking;
  bool get isInRoom => _isInRoom;
  bool get isConnected => mqttService.isConnected;
  LocationPoint? get currentLocation => _currentLocation;
  List<LocationPoint> get myTrail => List.unmodifiable(_myTrail);
  List<PeerUser> get onlinePeers =>
      _peers.values.where((p) => p.isOnline).toList();

  TrackerProvider() {
    _myName = 'Utente-${_myId.substring(5)}';
    _myColor = AppColors.getColorForId(_myId);
    mqttService = MqttService(cryptoService: cryptoService);
    _initIdentity();
  }

  Future<void> _initIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('tracker_my_id');
    if (savedId != null && savedId.trim().isNotEmpty) {
      _myId = savedId.trim();
    } else {
      await prefs.setString('tracker_my_id', _myId);
    }

    _myName = prefs.getString('tracker_my_name') ?? 'Utente-${_myId.substring(5)}';
    _myColor = AppColors.getColorForId(_myId);
    _cartoKey = prefs.getString('tracker_carto_key') ?? '';
    _brokerHost = prefs.getString('tracker_mqtt_broker') ?? AppConfig.mqttBrokerHost;
    _brokerUsername = prefs.getString('tracker_mqtt_username') ?? AppConfig.defaultMqttUsername;
    _brokerPassword = prefs.getString('tracker_mqtt_password') ?? AppConfig.defaultMqttPassword;
    notifyListeners();
  }

  /// Explicitly requests location and notification permissions from the smartphone on startup
  Future<bool> requestStartupPermissions() async {
    return await locationService.requestStartupPermissions();
  }

  /// Joins a room, derives encryption key and initializes background service
  Future<bool> joinRoom({
    required String groupName,
    required String password,
    String? userName,
    String? cartoKey,
    String? brokerHost,
    String? brokerUsername,
    String? brokerPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    _groupDisplayName = groupName.trim().isEmpty ? 'Volantini X' : groupName.trim();
    _roomId = RoomSlug.slugify(_groupDisplayName);
    _roomPassword = password.trim();

    if (userName != null && userName.trim().isNotEmpty) {
      _myName = userName.trim();
      await prefs.setString('tracker_my_name', _myName);
    }

    if (cartoKey != null && cartoKey.trim().isNotEmpty) {
      _cartoKey = cartoKey.trim();
      await prefs.setString('tracker_carto_key', _cartoKey);
    }

    if (brokerHost != null && brokerHost.trim().isNotEmpty) {
      _brokerHost = brokerHost.trim();
      await prefs.setString('tracker_mqtt_broker', _brokerHost);
    }

    if (brokerUsername != null && brokerUsername.trim().isNotEmpty) {
      _brokerUsername = brokerUsername.trim();
      await prefs.setString('tracker_mqtt_username', _brokerUsername);
    }

    if (brokerPassword != null && brokerPassword.trim().isNotEmpty) {
      _brokerPassword = brokerPassword.trim();
      await prefs.setString('tracker_mqtt_password', _brokerPassword);
    }

    if (_myId.isEmpty) {
      _myId = 'user-${Random().nextInt(999999).toString().padLeft(6, '0')}';
    }

    // Ensure location permissions are granted
    await locationService.checkAndRequestPermissions();

    // Derive E2EE Key
    await cryptoService.deriveKey(password: _roomPassword, roomId: _roomId);

    // Connect to MQTT Broker
    final connected = await mqttService.connect(
      roomId: _roomId,
      myId: _myId,
      brokerHost: _brokerHost,
      username: _brokerUsername,
      password: _brokerPassword,
    );
    if (!connected) {
      notifyListeners();
      return false;
    }

    _isInRoom = true;
    _peers.clear();

    // Listen to incoming decrypted peer events
    mqttService.incomingMessages.listen(_handleIncomingMessage);

    // Notify room of our presence
    await _broadcastJoin();

    // Configure and start background service
    BackgroundTrackingManager.updateServiceConfig(
      roomId: _roomId,
      password: _roomPassword,
      myId: _myId,
      myName: _myName,
      myColorHex: '#${_myColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      brokerHost: _brokerHost,
      brokerUsername: _brokerUsername,
      brokerPassword: _brokerPassword,
    );

    if (_isTracking) {
      await BackgroundTrackingManager.start();
      await fetchCurrentFix();
    }

    // Start background timers
    _peerCleanupTimer?.cancel();
    _peerCleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      notifyListeners();
    });

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _broadcastHeartbeat();
    });

    notifyListeners();
    return true;
  }

  /// Toggles tracking state and updates background service & network peers
  Future<void> toggleTracking() async {
    _isTracking = !_isTracking;
    notifyListeners();

    if (_isTracking) {
      await FeedbackService.playStartFeedback();
      await BackgroundTrackingManager.start();
      await fetchCurrentFix();
    } else {
      await FeedbackService.playStopFeedback();
      BackgroundTrackingManager.stop();
    }

    await mqttService.broadcast({
      'type': 'status',
      'id': _myId,
      'tracking': _isTracking,
    });
  }

  /// Fetches immediate GPS position
  Future<void> fetchCurrentFix() async {
    final point = await locationService.getCurrentPoint();
    if (point != null) {
      _currentLocation = point;
      _myTrail.add(point);
      notifyListeners();

      await mqttService.broadcast({
        'type': 'pos',
        'id': _myId,
        'name': _myName,
        'color': '#${_myColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'lat': point.lat,
        'lng': point.lng,
        'speed': point.speed,
        'heading': point.heading,
        'accuracy': point.accuracy,
        'time': point.timestamp,
      });
    }
  }

  Future<void> _broadcastJoin() async {
    await mqttService.broadcast({
      'type': 'join',
      'id': _myId,
      'name': _myName,
      'color': '#${_myColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'trail': _myTrail.map((p) => p.toJson()).toList(),
      'tracking': _isTracking,
    });
  }

  Future<void> _broadcastHeartbeat() async {
    await mqttService.broadcast({
      'type': 'ping',
      'id': _myId,
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final String? type = data['type'] as String?;
    final String? peerId = data['id'] as String?;
    if (type == null || peerId == null || peerId == _myId) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    PeerUser peer = _peers.putIfAbsent(
      peerId,
      () => PeerUser(
        id: peerId,
        name: data['name'] as String? ?? 'Partecipante',
        color: AppColors.getColorForId(peerId),
        lastSeen: now,
      ),
    );

    peer.lastSeen = now;
    if (data['name'] != null) peer.name = data['name'] as String;

    switch (type) {
      case 'join':
        if (data['tracking'] != null) peer.isTracking = data['tracking'] == true;
        if (data['trail'] is List) {
          final list = data['trail'] as List;
          peer.trail = list.map((e) => LocationPoint.fromJson(e)).toList();
          if (peer.trail.isNotEmpty) {
            peer.currentPosition = peer.trail.last;
          }
        }
        break;

      case 'pos':
        final point = LocationPoint.fromJson(data);
        peer.currentPosition = point;
        peer.trail.add(point);
        peer.isTracking = true;
        break;

      case 'status':
        if (data['tracking'] != null) peer.isTracking = data['tracking'] == true;
        break;

      case 'leave':
        _peers.remove(peerId);
        break;

      case 'ping':
        break;
    }

    notifyListeners();
  }

  /// Leaves room and stops background service
  Future<void> leaveRoom() async {
    await mqttService.broadcast({'type': 'leave', 'id': _myId});
    _peerCleanupTimer?.cancel();
    _heartbeatTimer?.cancel();
    BackgroundTrackingManager.stop();
    mqttService.disconnect();
    cryptoService.reset();
    _isInRoom = false;
    _peers.clear();
    _myTrail.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _peerCleanupTimer?.cancel();
    _heartbeatTimer?.cancel();
    mqttService.dispose();
    super.dispose();
  }
}
