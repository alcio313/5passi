import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
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
  static void updateServiceConfig({
    required String roomId,
    required String password,
    required String myId,
    required String myName,
    required String myColorHex,
    String? brokerHost,
    String? brokerUsername,
    String? brokerPassword,
  }) {
    if (!isSupported) return;
    try {
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

  // Listen to control instructions from the UI
  service.on('update_config').listen((event) async {
    if (event == null) return;
    roomId = event['roomId'] as String?;
    password = event['password'] as String?;
    myId = event['myId'] as String?;
    myName = event['myName'] as String?;
    myColorHex = event['myColorHex'] as String?;
    brokerHost = event['brokerHost'] as String?;
    brokerUsername = event['brokerUsername'] as String?;
    brokerPassword = event['brokerPassword'] as String?;

    if (password != null && roomId != null && myId != null) {
      await cryptoService.deriveKey(password: password!, roomId: roomId!);
      if (!mqttService.isConnected) {
        await mqttService.connect(
          roomId: roomId!,
          myId: myId!,
          brokerHost: brokerHost,
          username: brokerUsername,
          password: brokerPassword,
        );
      }
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

  // Background Sampling Loop (every 15 seconds)
  samplingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
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

      // Distance filter (<10m ignored)
      bool broadcastNeeded = true;
      if (lastLat != null && lastLng != null) {
        final distance = Haversine.distanceInMeters(
          lastLat!,
          lastLng!,
          position.latitude,
          position.longitude,
        );
        if (distance < AppConfig.minDistanceMeters) {
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
            brokerHost: brokerHost,
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
