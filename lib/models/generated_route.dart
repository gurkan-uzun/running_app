import 'package:latlong2/latlong.dart';
import 'poi.dart';
import 'user_preferences.dart';

/// Represents a generated route option with metadata
class GeneratedRoute {
  final String id; // "A", "B", "C"
  final String name; // "Balanced", "Discovery", "Favorites"
  final String description;
  final List<LatLng> points;
  final double distanceKm;
  final int estimatedMinutes;
  final List<Poi> pois;
  final Map<PoiCategory, int> categoryBreakdown;
  
  GeneratedRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.distanceKm,
    this.estimatedMinutes = 0,
    required this.pois,
    Map<PoiCategory, int>? categoryBreakdown,
  }) : categoryBreakdown = categoryBreakdown ?? _buildCategoryBreakdown(pois);
  
  static Map<PoiCategory, int> _buildCategoryBreakdown(List<Poi> pois) {
    Map<PoiCategory, int> breakdown = {};
    for (var poi in pois) {
      breakdown[poi.category] = (breakdown[poi.category] ?? 0) + 1;
    }
    return breakdown;
  }
  
  /// Get icon for category
  static String getCategoryIcon(PoiCategory category) {
    switch (category) {
      case PoiCategory.park: return '🌳';
      case PoiCategory.museum: return '🏛';
      case PoiCategory.viewpoint: return '👁';
      case PoiCategory.cafe: return '☕';
      case PoiCategory.restaurant: return '🍽';
      case PoiCategory.monument: return '🏛';
      case PoiCategory.nature: return '🌲';
      case PoiCategory.beach: return '🏖';
      case PoiCategory.other: return '📍';
    }
  }
  
  /// Get formatted category string like "🌳2 ☕3 🏛1"
  String get categoryString {
    return categoryBreakdown.entries
        .map((e) => '${getCategoryIcon(e.key)}${e.value}')
        .join(' ');
  }
  
  /// Estimated time based on ~6min/km running pace
  int get estimatedTimeMinutes {
    if (estimatedMinutes > 0) return estimatedMinutes;
    return (distanceKm * 6).round();
  }
}
