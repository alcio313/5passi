import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/tracker_provider.dart';

/// Modal bottom sheet detailing room participants and E2EE security state
class ParticipantsSheet extends StatelessWidget {
  const ParticipantsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final peers = tracker.onlinePeers;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Room Header & E2EE Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tracker.groupDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Stanza: #${tracker.roomId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: AppColors.success, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'E2EE AES-256',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 28),

          // Participants Count Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Partecipanti Connessi (${peers.length + 1})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share, color: AppColors.radarCore),
                tooltip: 'Copia nome stanza',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tracker.groupDisplayName));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nome gruppo copiato negli appunti!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Self Item
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: tracker.myColor,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              '${tracker.myName} (Tu)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              tracker.isTracking ? '🟢 Condivisione attiva' : '⏸️ In pausa',
              style: TextStyle(
                color: tracker.isTracking ? AppColors.success : Colors.white60,
                fontSize: 12,
              ),
            ),
          ),

          // Remote Peer List
          if (peers.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: peers.length,
                itemBuilder: (context, index) {
                  final peer = peers[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: peer.color,
                      child: Text(
                        peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      peer.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      peer.isTracking ? '🟢 In movimento' : '⏸️ In pausa',
                      style: TextStyle(
                        color: peer.isTracking ? AppColors.success : Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Leave Room Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                tracker.leaveRoom();
              },
              icon: const Icon(Icons.exit_to_app, color: AppColors.danger),
              label: const Text(
                'Esci dalla Stanza',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
