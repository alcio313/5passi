import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'location_point.dart';
import '../core/constants/app_colors.dart';

/// Represents another participant connected to the room (or past participant whose trail is preserved).
class PeerUser {
  final String id;
  String name;
  Color color;
  bool isTracking;
  int lastSeen;
  bool hasLeft;
  LocationPoint? currentPosition;
  List<LocationPoint> trail;

  PeerUser({
    required this.id,
    required this.name,
    Color? color,
    this.isTracking = true,
    required this.lastSeen,
    this.hasLeft = false,
    this.currentPosition,
    List<LocationPoint>? trail,
  })  : color = color ?? AppColors.getColorForId(id),
        trail = trail ?? [];

  String get colorHex =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  LatLng? get currentLatLng =>
      currentPosition != null ? LatLng(currentPosition!.lat, currentPosition!.lng) : null;

  bool get isOnline {
    if (hasLeft) return false;
    // 45 seconds timeout matching PWA peer cleanup
    final int now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSeen) < 45000;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': colorHex,
      'isTracking': isTracking,
      'lastSeen': lastSeen,
      'hasLeft': hasLeft,
      'trail': trail.map((p) => p.toJson()).toList(),
      if (currentPosition != null) 'currentPosition': currentPosition!.toJson(),
    };
  }

  factory PeerUser.fromJson(Map<String, dynamic> json) {
    Color parsedColor = AppColors.getColorForId(json['id'] as String? ?? 'user');
    if (json['color'] is String) {
      final hex = (json['color'] as String).replaceFirst('#', '');
      if (hex.length == 6) {
        parsedColor = Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        parsedColor = Color(int.parse(hex, radix: 16));
      }
    }

    final trailList = json['trail'] is List
        ? (json['trail'] as List).map((e) => LocationPoint.fromJson(e)).toList()
        : <LocationPoint>[];

    return PeerUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Partecipante',
      color: parsedColor,
      isTracking: json['isTracking'] == true,
      lastSeen: json['lastSeen'] is num ? (json['lastSeen'] as num).toInt() : 0,
      hasLeft: json['hasLeft'] == true,
      currentPosition: json['currentPosition'] != null
          ? LocationPoint.fromJson(json['currentPosition'])
          : (trailList.isNotEmpty ? trailList.last : null),
      trail: trailList,
    );
  }
}
