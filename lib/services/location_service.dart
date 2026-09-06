import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_config.dart';
import '../core/utils/haversine.dart';
import '../models/location_point.dart';

/// Manages native GPS acquisition, permissions, and Haversine noise filtering.
class LocationService {
  LocationPoint? _lastBroadcastPoint;

  LocationPoint? get lastBroadcastPoint => _lastBroadcastPoint;

  /// Requests all necessary permissions on app startup (Notifications & Location)
  Future<bool> requestStartupPermissions() async {
    // 1. Notification Permission (Android 13+ / iOS)
    try {
      final notifPlugin = FlutterLocalNotificationsPlugin();
      final androidNotif = notifPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidNotif?.requestNotificationsPermission();
    } catch (_) {}

    // 2. GPS Service Enabled check
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // 3. Location Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      // 4. Background permission for continuous screen-off tracking
      if (permission == LocationPermission.whileInUse) {
        await Geolocator.requestPermission();
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies and requests location permissions
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Requests background location permission explicitly (Android 10+)
  Future<bool> requestBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse) {
      final updated = await Geolocator.requestPermission();
      return updated == LocationPermission.always;
    }
    return permission == LocationPermission.always;
  }

  /// Provides a continuous real-time GPS stream with platform-tuned settings
  Stream<Position> getPositionStream({int distanceFilter = 4}) {
    LocationSettings locationSettings;

    if (!kIsWeb && Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 3),
      );
    } else if (!kIsWeb && Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Fetches a single GPS fix using high accuracy
  Future<LocationPoint?> getCurrentPoint() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final point = LocationPoint(
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
        timestamp: position.timestamp.millisecondsSinceEpoch,
      );

      return point;
    } catch (e) {
      return null;
    }
  }

  /// Evaluates if the new point exceeds the 10m threshold from the last broadcast
  bool shouldBroadcast(LocationPoint newPoint) {
    if (_lastBroadcastPoint == null) {
      _lastBroadcastPoint = newPoint;
      return true;
    }

    final double distance = Haversine.distanceInMeters(
      _lastBroadcastPoint!.lat,
      _lastBroadcastPoint!.lng,
      newPoint.lat,
      newPoint.lng,
    );

    if (distance >= AppConfig.minDistanceMeters) {
      _lastBroadcastPoint = newPoint;
      return true;
    }

    return false;
  }

  void reset() {
    _lastBroadcastPoint = null;
  }
}
