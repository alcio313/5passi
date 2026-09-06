import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_config.dart';
import '../../models/peer_user.dart';
import 'radar_marker_widget.dart';

/// Fullscreen interactive map rendering CARTO/OSM tiles, segmented polylines, and fluorescent radar markers
class TrackerMapView extends StatelessWidget {
  final MapController mapController;
  final LatLng? userPosition;
  final List<LatLng> userTrail;
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

  @override
  Widget build(BuildContext context) {
    final initialCenter = userPosition ?? const LatLng(41.9028, 12.4964); // Default to Rome

    // Prepare Peer Polylines
    final List<Polyline> polylines = [];

    // User trail polyline (thick 6px WCAG accessible)
    if (userTrail.length >= 2) {
      polylines.add(
        Polyline(
          points: userTrail,
          strokeWidth: 6.0,
          color: userColor.withValues(alpha: 0.85),
        ),
      );
    }

    // Remote peer trails
    for (final peer in peers) {
      final peerPoints = peer.trail.map((p) => p.toLatLng()).toList();
      if (peerPoints.length >= 2) {
        polylines.add(
          Polyline(
            points: peerPoints,
            strokeWidth: 5.0,
            color: peer.color.withValues(alpha: 0.8),
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

    // Peer Radar Markers
    for (final peer in peers) {
      if (peer.currentLatLng != null) {
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
