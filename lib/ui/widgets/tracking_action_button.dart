import 'package:flutter/material.dart';

/// Interactive toggle switch button:
/// - ON (isTracking = true): Vibrant Green with "CONDIVISIONE ATTIVA"
/// - OFF (isTracking = false): Vivid Red with "CONDIVISIONE SPENTA"
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
    // ON: Emerald Green | OFF: Vivid Crimson Red
    final Color activeColor = const Color(0xFF059669);
    final Color inactiveColor = const Color(0xFFDC2626);
    final Color currentColor = isTracking ? activeColor : inactiveColor;

    final String title =
        isTracking ? 'CONDIVISIONE ATTIVA' : 'CONDIVISIONE SPENTA';
    final String statusBadge = isTracking ? 'ON' : 'OFF';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(32),
        splashColor: Colors.white24,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: currentColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.90),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: currentColor.withValues(alpha: 0.55),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Status Icon Circle
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTracking ? Icons.sensors : Icons.sensors_off,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      isTracking
                          ? 'GPS attivo in tempo reale'
                          : 'Trasmissione GPS in pausa',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle Capsule Indicator (ON / OFF Slider)
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                width: 62,
                height: 34,
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  alignment:
                      isTracking ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        statusBadge,
                        style: TextStyle(
                          color: currentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
