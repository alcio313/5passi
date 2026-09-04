import 'package:flutter/material.dart';

/// High-contrast, accessible color palette mirroring the web app configuration.
class AppColors {
  // Slate Dark Theme base
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceVariant = Color(0xFF334155);
  static const Color border = Color(0xFF475569);

  // Status & Highlights
  static const Color primary = Color(0xFF0066FF);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Fluorescent radar & tracking marker
  static const Color radarPulse = Color(0x6600E5FF);
  static const Color radarCore = Color(0xFF00E5FF);

  // High-Contrast User Palette (identical to PALETTE in app.js)
  static const List<Color> userPalette = [
    Color(0xFF0066FF), // Vibrant Royal Blue
    Color(0xFFE60049), // Vivid Crimson Red
    Color(0xFF00A86B), // Jade Emerald Green
    Color(0xFF8A2BE2), // Deep Purple
    Color(0xFFFF6B00), // Electric Orange
    Color(0xFF008080), // Deep Teal
    Color(0xFFD90429), // Dark Coral Red
    Color(0xFF6A0DAD), // Deep Violet
  ];

  /// Generates a consistent color for a given user ID matching stringToColor() in app.js
  static Color getColorForId(String id) {
    if (id.isEmpty) return userPalette.first;
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = id.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final int index = hash.abs() % userPalette.length;
    return userPalette[index];
  }
}
