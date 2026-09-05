import 'package:flutter/material.dart';

/// Large, accessible touch button (64px height) to toggle tracking state
class TrackingActionButton extends StatelessWidget {
  final bool isTracking;
  final VoidCallback onPressed;

  const TrackingActionButton({
    super.key,
    required this.isTracking,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = isTracking
        ? const Color(0xFFE60049) // Vivid Crimson Red
        : const Color(0xFF00A86B); // Jade Emerald Green

    final String label = isTracking ? 'FERMA CONDIVISIONE' : 'AVVIA CONDIVISIONE';
    final IconData icon = isTracking ? Icons.stop_circle_outlined : Icons.play_circle_fill;

    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(color: Colors.white, width: 2.5),
          ),
          elevation: 6,
        ),
        icon: Icon(icon, size: 30),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
