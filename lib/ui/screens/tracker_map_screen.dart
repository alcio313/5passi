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

  void _confirmLeaveRoom(BuildContext context, TrackerProvider tracker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: AppColors.danger),
            SizedBox(width: 8),
            Text(
              'Esci dalla Stanza',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Sei sicuro di voler uscire da "${tracker.groupDisplayName}"? Il tracciamento GPS verrà interrotto.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              tracker.leaveRoom();
            },
            child: const Text('Esci'),
          ),
        ],
      ),
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

          // 🔝 Top Bar: Exit button & Room Badge / Participants Count
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Exit Room Button (In alto a sinistra)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: FloatingActionButton(
                      heroTag: 'exit_room_btn',
                      mini: true,
                      onPressed: () => _confirmLeaveRoom(context, tracker),
                      backgroundColor: AppColors.surface,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.danger, width: 1.5),
                      ),
                      tooltip: 'Esci dalla Stanza',
                      child: const Icon(Icons.exit_to_app, color: AppColors.danger, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Room Badge
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showParticipants(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.94),
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
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            Flexible(
                              child: Text(
                                tracker.groupDisplayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
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
                ],
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

          // 🎯 Recenter GPS Button (A metà schermo sul lato destro)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CompassRecenterButton(
                onPressed: () => _recenterOnUser(userPos),
              ),
            ),
          ),

          // 🚀 Bottom Action Area: Tracking Button (Spostato più in alto e protetto da SafeArea)
          SafeArea(
            bottom: true,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: TrackingActionButton(
                  isTracking: tracker.isTracking,
                  onPressed: () => tracker.toggleTracking(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
