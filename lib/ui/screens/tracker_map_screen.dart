import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/tracker_provider.dart';
import '../widgets/compass_recenter_button.dart';
import '../widgets/participants_sheet.dart';
import '../widgets/tracker_map_view.dart';
import '../widgets/tracking_action_button.dart';

/// Main tracking dashboard featuring full-screen map, accessible controls, and real-time HUD
class TrackerMapScreen extends StatefulWidget {
  const TrackerMapScreen({super.key});

  @override
  State<TrackerMapScreen> createState() => _TrackerMapScreenState();
}

class _TrackerMapScreenState extends State<TrackerMapScreen> {
  final MapController _mapController = MapController();

  void _recenterOnUser(LatLng? pos) {
    if (pos != null) {
      _mapController.move(pos, 16.5);
    }
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1.0);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1.0);
  }

  void _showParticipants(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ParticipantsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final userPos = tracker.currentLocation?.toLatLng();
    final userTrail = tracker.myTrail.map((p) => p.toLatLng()).toList();
    final onlineCount = tracker.onlinePeers.length + 1;

    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ Fullscreen Map
          TrackerMapView(
            mapController: _mapController,
            userPosition: userPos,
            userTrail: userTrail,
            userColor: tracker.myColor,
            userName: tracker.myName,
            isTracking: tracker.isTracking,
            peers: tracker.onlinePeers,
            cartoApiKey: tracker.cartoKey,
          ),

          // 🔝 Top Bar: Room Badge & Participants Count
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _showParticipants(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Live green pulse dot
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Room Name
                        Text(
                          tracker.groupDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // E2EE Lock Icon
                        const Icon(Icons.lock, color: AppColors.success, size: 14),
                        const SizedBox(width: 6),

                        const Text('•', style: TextStyle(color: Colors.white38)),
                        const SizedBox(width: 6),

                        // Participants Count
                        const Icon(Icons.people, color: AppColors.radarCore, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$onlineCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🔍 Zoom Buttons (Dedicated Screen Controls)
          Positioned(
            right: 16,
            top: 140,
            child: Column(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FloatingActionButton(
                    heroTag: 'zoom_in_btn',
                    mini: true,
                    onPressed: _zoomIn,
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FloatingActionButton(
                    heroTag: 'zoom_out_btn',
                    mini: true,
                    onPressed: _zoomOut,
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Icon(Icons.remove, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // 🎯 Recenter GPS Button
          Positioned(
            right: 16,
            bottom: 120,
            child: CompassRecenterButton(
              onPressed: () => _recenterOnUser(userPos),
            ),
          ),

          // 🚀 Bottom Action Area: Tracking Button & Status Pill
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Screen-off background indicator pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tracker.isTracking ? AppColors.success : Colors.white30,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tracker.isTracking ? Icons.battery_charging_full : Icons.pause_circle,
                        color: tracker.isTracking ? AppColors.success : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tracker.isTracking
                            ? 'Tracciamento a schermo spento: ATTIVO'
                            : 'Tracciamento in pausa',
                        style: TextStyle(
                          color: tracker.isTracking ? AppColors.success : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Large accessible action button
                TrackingActionButton(
                  isTracking: tracker.isTracking,
                  onPressed: () => tracker.toggleTracking(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
