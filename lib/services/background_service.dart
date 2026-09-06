import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_config.dart';
import '../core/utils/haversine.dart';
import 'crypto_service.dart';
import 'mqtt_service.dart';

/// Manages native background execution and Foreground Service for continuous GPS tracking
/// even when the screen is turned off or the app is minimized.
class BackgroundTrackingManager {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Background service is only needed and supported on mobile (Android/iOS)
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Emits location points registered by the background isolate to the UI isolate
  static Stream<Map<String, dynamic>?> get locationUpdates {
    if (!isSupported) return const Stream.empty();
    return _service.on('location_update');
  }

  /// Initializes the background service and notification channels
  static Future<void> initializeService() async {
    if (!isSupported) return;

    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        AppConfig.notificationChannelId,
        AppConfig.notificationChannelName,
        description: 'Notifica persistente per il tracciamento continuo in background',
        importance: Importance.low,
        showBadge: false,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStartBackgroundService,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: AppConfig.notificationChannelId,
          initialNotificationTitle: '5passi',
          initialNotificationContent: 'Servizio di tracciamento pronto',
          foregroundServiceNotificationId: AppConfig.notificationId,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStartBackgroundService,
          onBackground: onIosBackground,
        ),
      );
    } catch (e) {
      debugPrint('[BackgroundService] Failed to initialize: $e');
    }
  }

  /// Sends updated room/credentials context into the running background service isolate
  /// and persists it to SharedPreferences to prevent race condition on isolate startup.
  static Future<void> updateServiceConfig({
    required String roomId,
    required String password,
    required String myId,
    required String myName,
    required String myColorHex,
    String? brokerHost,
    String? brokerUsername,
    String? brokerPassword,
  }) async {
    if (!isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bg_room_id', roomId);
      await prefs.setString('bg_password', password);
      await prefs.setString('bg_my_id', myId);
      await prefs.setString('bg_my_name', myName);
      await prefs.setString('bg_my_color', myColorHex);
      if (brokerHost != null) await prefs.setString('bg_broker_host', brokerHost);
      if (brokerUsername != null) await prefs.setString('bg_broker_user', brokerUsername);
      if (brokerPassword != null) await prefs.setString('bg_broker_pass', brokerPassword);

      _service.invoke('update_config', {
        'roomId': roomId,
        'password': password,
        'myId': myId,
        'myName': myName,
        'myColorHex': myColorHex,
        'brokerHost': brokerHost,
        'brokerUsername': brokerUsername,
        'brokerPassword': brokerPassword,
      });
    } catch (_) {}
  }

  /// Starts the continuous background tracking service
  static Future<void> start() async {
    if (!isSupported) return;
    try {
      final isRunning = await _service.isRunning();
      if (!isRunning) {
        await _service.startService();
        await Future.delayed(const Duration(milliseconds: 250));
      }
      _service.invoke('set_tracking', {'tracking': true});
    } catch (_) {}
  }

  /// Stops or pauses the background tracking service
  static void stop() {
    if (!isSupported) return;
    try {
      _service.invoke('set_tracking', {'tracking': false});
    } catch (_) {}
  }

  /// Updates persistent notification from foreground UI
  static void updateNotificationInfo({required String title, required String content}) {
    if (!isSupported) return;
    try {
      _service.invoke('update_notification', {
        'title': title,
        'content': content,
      });
    } catch (_) {}
  }
}

/// Entrypoint executed in a separate background Dart isolate on iOS
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Entrypoint executed in a separate background Dart isolate on Android & iOS
@pragma('vm:entry-point')
void onStartBackgroundService(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final cryptoService = CryptoService();
  final mqttService = MqttService(cryptoService: cryptoService);

  String? roomId;
  String? password;
  String? myId;
  String? myName;
  String? myColorHex;
  String? brokerHost;
  String? brokerUsername;
  String? brokerPassword;
  bool isTracking = false;

  double? lastLat;
  double? lastLng;
  Timer? samplingTimer;

  // Load initial configuration from SharedPreferences to avoid race condition
  try {
    final prefs = await SharedPreferences.getInstance();
    roomId = prefs.getString('bg_room_id');
    password = prefs.getString('bg_password');
    myId = prefs.getString('bg_my_id');
    myName = prefs.getString('bg_my_name');
    myColorHex = prefs.getString('bg_my_color');
    brokerHost = prefs.getString('bg_broker_host');
    brokerUsername = prefs.getString('bg_broker_user');
    brokerPassword = prefs.getString('bg_broker_pass');

    if (password != null && roomId != null && myId != null) {
      await cryptoService.deriveKey(password: password, roomId: roomId);
      if (!mqttService.isConnected) {
        await mqttService.connect(
          roomId: roomId,
          myId: myId,
          customClientId: '${myId}_bg',
          brokerHost: brokerHost,
          username: brokerUsername,
          password: brokerPassword,
        );
      }
    }
  } catch (_) {}

  // Listen to control instructions from the UI
  service.on('update_config').listen((event) async {
    if (event == null) return;
    roomId = event['roomId'] as String? ?? roomId;
    password = event['password'] as String? ?? password;
    myId = event['myId'] as String? ?? myId;
    myName = event['myName'] as String? ?? myName;
    myColorHex = event['myColorHex'] as String? ?? myColorHex;
    brokerHost = event['brokerHost'] as String? ?? brokerHost;
    brokerUsername = event['brokerUsername'] as String? ?? brokerUsername;
    brokerPassword = event['brokerPassword'] as String? ?? brokerPassword;

    if (password != null && roomId != null && myId != null) {
      await cryptoService.deriveKey(password: password!, roomId: roomId!);
      if (!mqttService.isConnected) {
        await mqttService.connect(
          roomId: roomId!,
          myId: myId!,
          customClientId: '${myId!}_bg',
          brokerHost: brokerHost,
          username: brokerUsername,
          password: brokerPassword,
        );
      }
    }
  });

  service.on('update_notification').listen((event) {
    if (event == null) return;
    if (service is AndroidServiceInstance) {
      final title = event['title'] as String? ?? '5passi';
      final content = event['content'] as String? ?? '';
      service.setForegroundNotificationInfo(title: title, content: content);
    }
  });

  service.on('set_tracking').listen((event) {
    if (event == null) return;
    isTracking = event['tracking'] == true;

    if (service is AndroidServiceInstance) {
      if (isTracking) {
        service.setForegroundNotificationInfo(
          title: '5passi 🛰️',
          content: 'Tracciamento attivo a schermo spento',
        );
      } else {
        service.setForegroundNotificationInfo(
          title: '5passi ⏸️',
          content: 'Tracciamento in pausa',
        );
      }
    }
  });

  service.on('stop_service').listen((event) {
    samplingTimer?.cancel();
    mqttService.disconnect();
    service.stopSelf();
  });

  // Background Sampling Loop (every 10 seconds for reliable position tracking)
  samplingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (!isTracking || roomId == null || myId == null || !cryptoService.hasKey) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      // Distance filter (< 5m ignored to filter jitter)
      bool broadcastNeeded = true;
      if (lastLat != null && lastLng != null) {
        final distance = Haversine.distanceInMeters(
          lastLat!,
          lastLng!,
          position.latitude,
          position.longitude,
        );
        if (distance < 5.0) {
          broadcastNeeded = false;
        }
      }

      if (broadcastNeeded) {
        lastLat = position.latitude;
        lastLng = position.longitude;

        if (!mqttService.isConnected) {
          await mqttService.connect(
            roomId: roomId!,
            myId: myId!,
            customClientId: '${myId!}_bg',
            brokerHost: brokerHost,
            username: brokerUsername,
            password: brokerPassword,
          );
        }

        final posPayload = {
          'type': 'pos',
          'id': myId,
          'name': myName ?? 'Mobile User',
          'color': myColorHex ?? '#0066FF',
          'lat': position.latitude,
          'lng': position.longitude,
          'speed': position.speed,
          'heading': position.heading,
          'accuracy': position.accuracy,
          'time': DateTime.now().millisecondsSinceEpoch,
        };

        await mqttService.broadcast(posPayload);

        // Notify UI isolate about new location
        service.invoke('location_update', posPayload);

        // Update foreground persistent notification info
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '5passi • In Movimento',
            content:
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} (±${position.accuracy.toStringAsFixed(0)}m)',
          );
        }
      }
    } catch (_) {}
  });
}
