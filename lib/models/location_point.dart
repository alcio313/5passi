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
      'coord': [lat, lng],
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
      'time': timestamp,
      if (isGap) 'isGap': true,
    };
  }

  factory LocationPoint.fromJson(dynamic json) {
    if (json is List) {
      return LocationPoint(
        lat: (json[0] as num).toDouble(),
        lng: (json[1] as num).toDouble(),
        isGap: json.length > 2 && (json[2] == 1 || json[2] == true),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final map = json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json as Map);
    double latitude;
    double longitude;
    if (map['coord'] is List) {
      final coordList = map['coord'] as List;
      latitude = (coordList[0] as num).toDouble();
      longitude = (coordList[1] as num).toDouble();
    } else {
      latitude = (map['lat'] as num? ?? 0.0).toDouble();
      longitude = (map['lng'] as num? ?? 0.0).toDouble();
    }

    return LocationPoint(
      lat: latitude,
      lng: longitude,
      heading: map['heading'] != null ? (map['heading'] as num).toDouble() : null,
      speed: map['speed'] != null ? (map['speed'] as num).toDouble() : null,
      accuracy: map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
      timestamp: map['time'] is num
          ? (map['time'] as num).toInt()
          : (map['timestamp'] is num ? (map['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch),
      isGap: map['isGap'] == true,
    );
  }
}
