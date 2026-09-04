import 'package:flutter/services.dart';

/// Provides sensory haptic feedback matching the Web Vibration & Audio APIs
class FeedbackService {
  /// Feedback triggered when tracking starts
  static Future<void> playStartFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Feedback triggered when tracking is stopped or paused
  static Future<void> playStopFeedback() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
