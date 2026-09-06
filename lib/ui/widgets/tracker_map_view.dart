import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_config.dart';
import '../../models/location_point.dart';
import '../../models/peer_user.dart';
import 'radar_marker_widget.dart';

/// Fullscreen interactive map rendering CARTO/OSM tiles, segmented polylines, and fluorescent radar markers
class TrackerMapView extends StatelessWidget {
  final MapController mapController;
  final LatLng? userPosition;
  final List<LocationPoint> userTrail;
  final Color userColor;
  final String userName;
  final bool isTracking;
  final List<PeerUser> peers;
  final String cartoApiKey;

  const TrackerMapView({
    super.key,
    required this.mapController,
    this.userPosition,
    required this.userTrail,
    required this.userColor,
    required this.userName,
    required this.isTracking,
    required this.peers,
    this.cartoApiKey = '',
  });

  String _getTileUrl() {
    if (cartoApiKey.isNotEmpty) {
      return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png?key=$cartoApiKey';
    }
    return AppConfig.defaultCartoTileUrl;
  }

  /// Splits a sequence of recorded points into independent polyline segments at each gap/pause
  List<List<LatLng>> _splitIntoSegments(List<LocationPoint> points) {
    if (points.isEmpty) return const [];
    final List<List<LatLng>> segments = [];
    List<LatLng> currentSegment = [];

    for (final p in points) {
      if (p.isGap && currentSegment.isNotEmpty) {
        if (currentSegment.length >= 2) {
          segments.add(currentSegment);
        }
        currentSegment = [p.toLatLng()];
      } else {
        currentSegment.add(p.toLatLng());
      }
    }
    if (currentSegment.length >= 2) {
      segments.add(currentSegment);
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = userPosition ?? const LatLng(41.9028, 12.4964); // Default to Rome

    // Prepare Peer Polylines
    final List<Polyline> polylines = [];

    // User trail polylines (thick 6px WCAG accessible, split across paused intervals)
    final userSegments = _splitIntoSegments(userTrail);
    for (final segment in userSegments) {
      polylines.add(
        Polyline(
          points: segment,
          strokeWidth: 6.0,
          color: userColor.withValues(alpha: 0.85),
        ),
      );
    }

    // Remote peer trails (both active participants and historical paths)
    for (final peer in peers) {
      final peerSegments = _splitIntoSegments(peer.trail);
      final double opacity = peer.isOnline ? 0.85 : 0.60;
      final double strokeWidth = peer.isOnline ? 5.5 : 4.5;
      for (final segment in peerSegments) {
        polylines.add(
          Polyline(
            points: segment,
            strokeWidth: strokeWidth,
            color: peer.color.withValues(alpha: opacity),
          ),
        );
      }
    }

    // Prepare Markers
    final List<Marker> markers = [];

    // User Radar Marker
    if (userPosition != null) {
      markers.add(
        Marker(
          point: userPosition!,
          width: 180,
          height: 90,
          child: RadarMarkerWidget(
            label: userName,
            color: userColor,
            isSelf: true,
            isTracking: isTracking,
          ),
        ),
      );
    }

    // Peer Radar Markers (only rendered for active/online participants)
    for (final peer in peers) {
      if (peer.isOnline && peer.currentLatLng != null) {
        markers.add(
          Marker(
            point: peer.currentLatLng!,
            width: 180,
            height: 90,
            child: RadarMarkerWidget(
              label: peer.name,
              color: peer.color,
              isSelf: false,
              isTracking: peer.isTracking,
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 15.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Tile Layer
        TileLayer(
          urlTemplate: _getTileUrl(),
          fallbackUrl: AppConfig.osmFallbackTileUrl,
          userAgentPackageName: 'com.example.live_map_tracker',
        ),

        // Trail Polylines
        PolylineLayer(polylines: polylines),

        // Fluorescent Radar Markers
        MarkerLayer(markers: markers),
      ],
    );
  }
}
