import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/utils/haversine.dart';
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
  Timer? _desktopSamplingTimer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Map<String, dynamic>?>? _bgLocationSubscription;

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
    await BackgroundTrackingManager.updateServiceConfig(
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
      _startLiveTracking();
      await fetchCurrentFix();
    }

    // Notify room of our presence
    await _broadcastJoin();

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

  /// Starts real-time continuous GPS tracking stream in foreground and listens to background service
  void _startLiveTracking() {
    _stopLiveTracking();

    // 1. Continuous native GPS stream
    try {
      _positionSubscription = locationService.getPositionStream(distanceFilter: 4).listen(
        (Position position) {
          if (!_isTracking || !_isInRoom) return;
          final point = LocationPoint(
            lat: position.latitude,
            lng: position.longitude,
            speed: position.speed,
            heading: position.heading,
            accuracy: position.accuracy,
            timestamp: position.timestamp.millisecondsSinceEpoch,
          );
          _handleNewUserPosition(point);
        },
        onError: (error) {
          debugPrint('⚠️ [TrackerProvider] Error in GPS stream: $error');
        },
      );
    } catch (e) {
      debugPrint('⚠️ [TrackerProvider] Failed to start position stream: $e');
    }

    // 2. Ingest points captured by background isolate (e.g. while phone screen was locked)
    _bgLocationSubscription = BackgroundTrackingManager.locationUpdates.listen(
      (Map<String, dynamic>? event) {
        if (event == null || !_isInRoom || !_isTracking) return;
        try {
          final point = LocationPoint.fromJson(event);
          _handleNewUserPosition(point);
        } catch (_) {}
      },
    );

    // 3. Fallback periodic sampling on desktop
    _startDesktopSamplingIfNeeded();
  }

  /// Cancels live GPS streams and timers
  void _stopLiveTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _bgLocationSubscription?.cancel();
    _bgLocationSubscription = null;
    _desktopSamplingTimer?.cancel();
    _desktopSamplingTimer = null;
  }

  /// Appends a new position to myTrail, updates currentLocation, and broadcasts to room
  void _handleNewUserPosition(LocationPoint point) {
    // Noise filter: ignore very inaccurate GPS fixes (>80m) if we already have a fix
    if (point.accuracy != null && point.accuracy! > 80.0 && _currentLocation != null) {
      return;
    }

    // Distance filter: ignore jitter (<3.5m)
    if (_myTrail.isNotEmpty) {
      final last = _myTrail.last;
      final distance = Haversine.distanceInMeters(
        last.lat,
        last.lng,
        point.lat,
        point.lng,
      );
      if (distance < 3.5) {
        return;
      }
    }

    _currentLocation = point;
    _myTrail.add(point);
    notifyListeners();

    // Broadcast position update to room
    _broadcastPosition(point);

    // Update persistent notification on Android
    final accuracyStr = point.accuracy != null ? ' (±${point.accuracy!.toStringAsFixed(0)}m)' : '';
    BackgroundTrackingManager.updateNotificationInfo(
      title: '5passi • In Movimento',
      content:
          '${point.lat.toStringAsFixed(4)}, ${point.lng.toStringAsFixed(4)}$accuracyStr',
    );
  }

  Future<void> _broadcastPosition(LocationPoint point) async {
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

  /// Toggles tracking state and updates background service & network peers
  Future<void> toggleTracking() async {
    _isTracking = !_isTracking;
    notifyListeners();

    if (_isTracking) {
      await FeedbackService.playStartFeedback();
      await BackgroundTrackingManager.start();
      _startLiveTracking();
      await fetchCurrentFix();
    } else {
      await FeedbackService.playStopFeedback();
      _stopLiveTracking();
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
      _handleNewUserPosition(point);
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

  void _startDesktopSamplingIfNeeded() {
    _desktopSamplingTimer?.cancel();
    if (!BackgroundTrackingManager.isSupported) {
      _desktopSamplingTimer = Timer.periodic(
        const Duration(milliseconds: AppConfig.samplingIntervalMs),
        (_) {
          if (_isTracking && _isInRoom) {
            fetchCurrentFix();
          }
        },
      );
    }
  }

  /// Leaves room and stops background service
  Future<void> leaveRoom() async {
    await mqttService.broadcast({'type': 'leave', 'id': _myId});
    _peerCleanupTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stopLiveTracking();
    BackgroundTrackingManager.stop();
    mqttService.disconnect();
    cryptoService.reset();
    _isInRoom = false;
    _peers.clear();
    _myTrail.clear();
    _currentLocation = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _peerCleanupTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stopLiveTracking();
    mqttService.dispose();
    super.dispose();
  }
}
