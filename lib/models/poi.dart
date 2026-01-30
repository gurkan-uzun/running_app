import '../models/user_preferences.dart';

/// POI (Point of Interest) model with category mapping
class Poi {
  final int id;
  final double lat;
  final double lon;
  final String name;
  final PoiCategory category;
  final String rawCategory; // Original OSM category
  final double rating;

  Poi({
    required this.id,
    required this.lat,
    required this.lon,
    required this.name,
    required this.category,
    this.rawCategory = '',
    this.rating = 0.0,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    final rawCategory = _extractRawCategory(json['tags']);
    return Poi(
      id: json['id'] as int,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      name: json['tags']?['name'] ?? 'Unknown',
      category: _mapToCategory(rawCategory, json['tags']),
      rawCategory: rawCategory,
    );
  }

  /// Extract raw category from OSM tags
  static String _extractRawCategory(Map<String, dynamic>? tags) {
    if (tags == null) return 'unknown';
    if (tags.containsKey('amenity')) return tags['amenity'];
    if (tags.containsKey('tourism')) return tags['tourism'];
    if (tags.containsKey('leisure')) return tags['leisure'];
    if (tags.containsKey('natural')) return tags['natural'];
    return 'other';
  }

  /// Map OSM categories to our defined PoiCategory enum
  static PoiCategory _mapToCategory(String raw, Map<String, dynamic>? tags) {
    // Parks
    if (raw == 'park' || raw == 'garden' || raw == 'playground' ||
        raw == 'recreation_ground' || raw == 'dog_park') {
      return PoiCategory.park;
    }
    
    // Museums
    if (raw == 'museum' || raw == 'gallery' || raw == 'arts_centre') {
      return PoiCategory.museum;
    }
    
    // Viewpoints
    if (raw == 'viewpoint' || raw == 'observation_tower' || 
        (tags?['tourism'] == 'viewpoint')) {
      return PoiCategory.viewpoint;
    }
    
    // Cafes
    if (raw == 'cafe' || raw == 'coffee_shop' || raw == 'ice_cream') {
      return PoiCategory.cafe;
    }
    
    // Restaurants
    if (raw == 'restaurant' || raw == 'fast_food' || raw == 'food_court') {
      return PoiCategory.restaurant;
    }
    
    // Monuments
    if (raw == 'monument' || raw == 'memorial' || raw == 'artwork' ||
        raw == 'attraction' || raw == 'castle' || raw == 'ruins' ||
        tags?['historic'] != null) {
      return PoiCategory.monument;
    }
    
    // Beach - CHECK BEFORE nature to avoid catching natural=beach
    if (raw == 'beach' || raw == 'swimming_area' || raw == 'marina' || raw == 'Beach' ||
        tags?['natural'] == 'beach') {
      return PoiCategory.beach;
    }
    
    // Nature - only major natural features worth visiting, NOT trees/bushes/rocks
    final naturalValue = tags?['natural'];
    final validNatureValues = ['nature_reserve', 'forest', 'wood', 'wetland', 
                                'cliff', 'peak', 'volcano', 'valley', 'spring',
                                'hot_spring', 'geyser', 'cave_entrance', 'glacier'];
    if (raw == 'nature_reserve' || 
        (naturalValue != null && validNatureValues.contains(naturalValue))) {
      return PoiCategory.nature;
    }
    
    // Default - unrecognized category
    return PoiCategory.other;
  }

  /// Check if this POI matches user preferences
  bool matchesPreferences(UserPreferences prefs) {
    // 'other' category is always hidden when user has specific preferences
    if (category == PoiCategory.other && prefs.preferredCategories.isNotEmpty) {
      return false;
    }
    
    // If user has no preferred categories, show all except avoided ones
    if (prefs.preferredCategories.isEmpty) {
      return !prefs.avoidCategories.contains(category);
    }
    
    // Show only preferred categories, excluding avoided ones
    return prefs.preferredCategories.contains(category) &&
           !prefs.avoidCategories.contains(category);
  }

  /// Get display icon for this category
  String get icon => category.icon;

  /// Get display name for this category
  String get categoryDisplayName => category.displayName;

  @override
  String toString() {
    return 'Poi{id: $id, name: $name, category: ${category.name}, lat: $lat, lon: $lon}';
  }
}
