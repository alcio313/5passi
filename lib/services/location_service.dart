import 'package:geolocator/geolocator.dart';
import '../core/constants/app_config.dart';
import '../core/utils/haversine.dart';
import '../models/location_point.dart';

/// Manages native GPS acquisition, permissions, and Haversine noise filtering.
class LocationService {
  LocationPoint? _lastBroadcastPoint;

  LocationPoint? get lastBroadcastPoint => _lastBroadcastPoint;

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
