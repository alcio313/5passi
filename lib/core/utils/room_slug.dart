/// Utilities for slugifying and formatting room/group names,
/// ensuring interoperability between web and mobile links.
class RoomSlug {
  /// Converts a user-friendly name into an ASCII/URL slug
  /// e.g. "Monte Bianco" -> "monte-bianco"
  static String slugify(String? name) {
    if (name == null || name.trim().isEmpty) return 'volantini-x';
    String cleaned = name.toLowerCase().trim();
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9àèéìòùáéíóú_-]'), '-');
    cleaned = cleaned.replaceAll(RegExp(r'-+'), '-');
    cleaned = cleaned.replaceAll(RegExp(r'^-|-$'), '');
    return cleaned.isEmpty ? 'volantini-x' : cleaned;
  }

  /// Converts a slug back into a title-cased display name
  /// e.g. "monte-bianco" -> "Monte Bianco"
  static String formatSlug(String? slug) {
    if (slug == null || slug.trim().isEmpty) return 'Volantini X';
    return slug
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
