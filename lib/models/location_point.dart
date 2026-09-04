import 'package:latlong2/latlong.dart';

/// Represents a single recorded geographic location coordinate.
class LocationPoint {
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final int timestamp;
  final bool isGap;

  LocationPoint({
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    this.accuracy,
    required this.timestamp,
    this.isGap = false,
  });

  LatLng toLatLng() => LatLng(lat, lng);

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
      'time': timestamp,
      if (isGap) 'isGap': true,
    };
  }

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      timestamp: json['time'] is num ? (json['time'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      isGap: json['isGap'] == true,
    );
  }
}
