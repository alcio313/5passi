import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'location_point.dart';
import '../core/constants/app_colors.dart';

/// Represents another participant connected to the room.
class PeerUser {
  final String id;
  String name;
  Color color;
  bool isTracking;
  int lastSeen;
  LocationPoint? currentPosition;
  List<LocationPoint> trail;

  PeerUser({
    required this.id,
    required this.name,
    Color? color,
    this.isTracking = true,
    required this.lastSeen,
    this.currentPosition,
    List<LocationPoint>? trail,
  })  : color = color ?? AppColors.getColorForId(id),
        trail = trail ?? [];

  LatLng? get currentLatLng =>
      currentPosition != null ? LatLng(currentPosition!.lat, currentPosition!.lng) : null;

  bool get isOnline {
    // 45 seconds timeout matching PWA peer cleanup
    final int now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSeen) < 45000;
  }
}
