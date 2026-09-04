import 'package:flutter/material.dart';

/// Senior-friendly large circular button (60px) to recenter the map on current GPS location
class CompassRecenterButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CompassRecenterButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: FloatingActionButton(
        heroTag: 'recenter_btn',
        onPressed: onPressed,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 2.5),
        ),
        child: const Icon(
          Icons.my_location,
          color: Color(0xFF00E5FF),
          size: 32,
        ),
      ),
    );
  }
}
