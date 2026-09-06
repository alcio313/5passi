import 'dart:async';
import 'dart:convert';
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
class TrackerProvider extends ChangeNotifier with WidgetsBindingObserver {
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
  Timer? _saveDebounceTimer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Map<String, dynamic>?>? _bgLocationSubscription;
  StreamSubscription? _incomingMessagesSubscription;

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
  List<PeerUser> get allPeers => _peers.values.toList();
  List<PeerUser> get onlinePeers =>
      _peers.values.where((p) => p.isOnline && !p.hasLeft).toList();
  List<PeerUser> get offlinePeers =>
      _peers.values.where((p) => !p.isOnline || p.hasLeft).toList();

  TrackerProvider() {
    _myName = 'Utente-${_myId.substring(5)}';
    _myColor = AppColors.getColorForId(_myId);
    mqttService = MqttService(cryptoService: cryptoService);
    mqttService.onReconnected = _onNetworkReconnected;
    WidgetsBinding.instance.addObserver(this);
    _initIdentity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isInRoom) {
      debugPrint('📱 [TrackerProvider] App riattivata in primo piano! Richiesta sincronizzazione percorso...');
      _broadcastSyncRequest();
      if (_isTracking) {
        fetchCurrentFix();
      }
    }
  }

  void _onNetworkReconnected() {
    if (!_isInRoom) return;
    debugPrint('🔄 [TrackerProvider] Riconnessione MQTT riuscita! Sincronizzazione percorsi in tempo reale...');
    _broadcastJoin();
    _broadcastSyncRequest();
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

    // Load any saved historical trails for this room
    await _loadRoomHistory();

    // Listen to incoming decrypted peer events
    _incomingMessagesSubscription?.cancel();
    _incomingMessagesSubscription =
        mqttService.incomingMessages.listen(_handleIncomingMessage);

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

    // Notify room of our presence (with current trail)
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

    _saveRoomHistoryDebounced();
  }

  Future<void> _broadcastPosition(LocationPoint point) async {
    await mqttService.broadcast({
      'type': 'pos',
      'id': _myId,
      'name': _myName,
      'color': '#${_myColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'lat': point.lat,
      'lng': point.lng,
      'coord': [point.lat, point.lng],
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

  /// Broadcasts a request to all peers (or a specific peer) to synchronize historical trails
  Future<void> _broadcastSyncRequest({String target = 'all'}) async {
    if (!_isInRoom || !isConnected) return;
    await mqttService.broadcast({
      'type': 'sync_request',
      'id': _myId,
      'target': target,
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final String? type = data['type'] as String?;
    final String? peerId = data['id'] as String?;
    if (type == null || peerId == null || peerId == _myId) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final bool isExistingPeer = _peers.containsKey(peerId);
    final PeerUser peer = _peers.putIfAbsent(
      peerId,
      () => PeerUser(
        id: peerId,
        name: data['name'] as String? ?? 'Partecipante',
        color: AppColors.getColorForId(peerId),
        lastSeen: now,
      ),
    );

    // Detect if this peer was previously offline or is completely new to the session
    final bool wasOffline = !isExistingPeer || !peer.isOnline || peer.hasLeft;

    if (data['name'] != null && (data['name'] as String).isNotEmpty) {
      peer.name = data['name'] as String;
    }

    switch (type) {
      case 'join':
        peer.hasLeft = false;
        peer.lastSeen = now;
        if (data['tracking'] != null) peer.isTracking = data['tracking'] == true;
        if (data['trail'] is List) {
          final list = data['trail'] as List;
          final incoming = list.map((e) => LocationPoint.fromJson(e)).toList();
          _mergePeerTrail(peer, incoming);
        }
        // Share our own trail and all historical room trails with the newcomer
        _shareRoomHistoryWithJoiner();
        _saveRoomHistoryDebounced();
        break;

      case 'sync':
        if (data['tracking'] != null) peer.isTracking = data['tracking'] == true;
        if (data['hasLeft'] != null) peer.hasLeft = data['hasLeft'] == true;
        if (data['isOnline'] == false) {
          peer.lastSeen = 0;
        } else {
          peer.lastSeen = now;
        }
        if (data['trail'] is List) {
          final list = data['trail'] as List;
          final incoming = list.map((e) => LocationPoint.fromJson(e)).toList();
          _mergePeerTrail(peer, incoming);
        }
        _saveRoomHistoryDebounced();
        break;

      case 'sync_request':
        // A peer (or the whole room) requests an immediate sync of current and past trails
        final target = data['target'] as String?;
        if (target == null || target == 'all' || target == _myId) {
          debugPrint('📥 [TrackerProvider] Ricevuto sync_request da $peerId, sincronizzazione scia...');
          _shareRoomHistoryWithJoiner();
        }
        break;

      case 'pos':
        peer.hasLeft = false;
        peer.lastSeen = now;
        final point = LocationPoint.fromJson(data);
        peer.currentPosition = point;
        peer.trail.add(point);
        peer.isTracking = true;

        // If this peer just transitioned from offline to online, request full trail sync immediately!
        if (wasOffline) {
          debugPrint('🛰️ [TrackerProvider] Peer $peerId ha inviato posizione ed è tornato ONLINE! Sincronizzazione percorso in tempo reale...');
          _broadcastSyncRequest(target: peerId);
          _shareRoomHistoryWithJoiner();
        }
        _saveRoomHistoryDebounced();
        break;

      case 'status':
        peer.lastSeen = now;
        if (data['tracking'] != null) peer.isTracking = data['tracking'] == true;
        if (wasOffline) {
          _broadcastSyncRequest(target: peerId);
          _shareRoomHistoryWithJoiner();
        }
        break;

      case 'leave':
        // Preserve peer's completed trail in memory! Hide active radar marker only.
        peer.isTracking = false;
        peer.hasLeft = true;
        peer.currentPosition = null;
        _saveRoomHistory();
        break;

      case 'ping':
        peer.lastSeen = now;
        peer.hasLeft = false;
        // If peer just came back online via heartbeat, request full trail sync immediately!
        if (wasOffline) {
          debugPrint('🛰️ [TrackerProvider] Peer $peerId è tornato ONLINE via heartbeat! Sincronizzazione percorso in tempo reale...');
          _broadcastSyncRequest(target: peerId);
          _shareRoomHistoryWithJoiner();
        }
        break;
    }

    notifyListeners();
  }

  /// Sends both own trail and all known peers' trails to catch up a new participant
  Future<void> _shareRoomHistoryWithJoiner() async {
    // Add small randomized delay (150-450ms) to avoid simultaneous network collisions
    await Future.delayed(Duration(milliseconds: 150 + Random().nextInt(300)));
    if (!_isInRoom || !isConnected) return;

    // 1. Share own trail if non-empty
    if (_myTrail.isNotEmpty) {
      await mqttService.broadcast({
        'type': 'sync',
        'id': _myId,
        'name': _myName,
        'color': '#${_myColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'trail': _myTrail.map((p) => p.toJson()).toList(),
        'tracking': _isTracking,
        'isOnline': true,
        'hasLeft': false,
      });
    }

    // 2. Share past trails of all known peers (active, offline, or exited)
    for (final pastPeer in _peers.values) {
      if (pastPeer.id != _myId && pastPeer.trail.isNotEmpty) {
        await mqttService.broadcast({
          'type': 'sync',
          'id': pastPeer.id,
          'name': pastPeer.name,
          'color': pastPeer.colorHex,
          'trail': pastPeer.trail.map((p) => p.toJson()).toList(),
          'tracking': pastPeer.isTracking,
          'isOnline': pastPeer.isOnline,
          'hasLeft': pastPeer.hasLeft,
        });
      }
    }
  }

  /// Merges incoming points into a peer's trail, deduplicating by timestamp and coordinates
  void _mergePeerTrail(PeerUser peer, List<LocationPoint> incoming) {
    if (incoming.isEmpty) return;
    if (peer.trail.isEmpty) {
      peer.trail.addAll(incoming);
    } else {
      final existingKeys = <String>{};
      for (final p in peer.trail) {
        existingKeys.add('${p.timestamp}_${p.lat.toStringAsFixed(6)}_${p.lng.toStringAsFixed(6)}');
      }
      for (final p in incoming) {
        final key = '${p.timestamp}_${p.lat.toStringAsFixed(6)}_${p.lng.toStringAsFixed(6)}';
        if (!existingKeys.contains(key)) {
          peer.trail.add(p);
          existingKeys.add(key);
        }
      }
      peer.trail.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    if (peer.trail.isNotEmpty && !peer.hasLeft) {
      peer.currentPosition = peer.trail.last;
    }
  }

  void _saveRoomHistoryDebounced() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 4), () {
      _saveRoomHistory();
    });
  }

  /// Loads locally stored room trails from previous sessions
  Future<void> _loadRoomHistory() async {
    if (_roomId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('room_history_$_roomId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        if (data['myTrail'] is List) {
          final list = data['myTrail'] as List;
          final loadedTrail = list.map((e) => LocationPoint.fromJson(e)).toList();
          final existingTimes = _myTrail.map((p) => p.timestamp).toSet();
          for (final p in loadedTrail) {
            if (!existingTimes.contains(p.timestamp)) {
              _myTrail.add(p);
              existingTimes.add(p.timestamp);
            }
          }
          _myTrail.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          if (_myTrail.isNotEmpty && _currentLocation == null) {
            _currentLocation = _myTrail.last;
          }
        }
        if (data['peers'] is List) {
          final pList = data['peers'] as List;
          for (final pJson in pList) {
            if (pJson is Map<String, dynamic>) {
              final peer = PeerUser.fromJson(pJson);
              if (peer.id.isNotEmpty && peer.id != _myId) {
                final existing = _peers[peer.id];
                if (existing == null) {
                  _peers[peer.id] = peer;
                } else {
                  _mergePeerTrail(existing, peer.trail);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [TrackerProvider] Error loading room history: $e');
    }
  }

  /// Saves complete room trail history into local device storage
  Future<void> _saveRoomHistory() async {
    if (_roomId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData = {
        'myTrail': _myTrail.map((p) => p.toJson()).toList(),
        'peers': _peers.values.map((p) => p.toJson()).toList(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('room_history_$_roomId', jsonEncode(historyData));
    } catch (e) {
      debugPrint('⚠️ [TrackerProvider] Error saving room history: $e');
    }
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
    await _saveRoomHistory();
    _incomingMessagesSubscription?.cancel();
    _incomingMessagesSubscription = null;
    _saveDebounceTimer?.cancel();
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
    WidgetsBinding.instance.removeObserver(this);
    _incomingMessagesSubscription?.cancel();
    _saveDebounceTimer?.cancel();
    _peerCleanupTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stopLiveTracking();
    mqttService.dispose();
    super.dispose();
  }
}
