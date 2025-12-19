/// POI categories for user preferences
enum PoiCategory {
  park,
  museum,
  viewpoint,
  cafe,
  restaurant,
  monument,
  nature,
  beach,
}

extension PoiCategoryExtension on PoiCategory {
  String get displayName {
    switch (this) {
      case PoiCategory.park:
        return 'Parks';
      case PoiCategory.museum:
        return 'Museums';
      case PoiCategory.viewpoint:
        return 'Viewpoints';
      case PoiCategory.cafe:
        return 'Cafes';
      case PoiCategory.restaurant:
        return 'Restaurants';
      case PoiCategory.monument:
        return 'Monuments';
      case PoiCategory.nature:
        return 'Nature';
      case PoiCategory.beach:
        return 'Beaches';
    }
  }

  String get icon {
    switch (this) {
      case PoiCategory.park:
        return '🌳';
      case PoiCategory.museum:
        return '🏛️';
      case PoiCategory.viewpoint:
        return '👀';
      case PoiCategory.cafe:
        return '☕';
      case PoiCategory.restaurant:
        return '🍽️';
      case PoiCategory.monument:
        return '🗿';
      case PoiCategory.nature:
        return '🏞️';
      case PoiCategory.beach:
        return '🏖️';
    }
  }
}

/// User preferences for POI filtering and route planning
class UserPreferences {
  final double targetDistance; // in km
  final String routeType; // 'shortest', 'scenic', 'footpath-first'
  final List<PoiCategory> preferredCategories;
  final List<PoiCategory> avoidCategories;

  UserPreferences({
    this.targetDistance = 5.0,
    this.routeType = 'shortest',
    this.preferredCategories = const [],
    this.avoidCategories = const [],
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      targetDistance: (map['targetDistance'] ?? 5.0).toDouble(),
      routeType: map['routeType'] ?? 'shortest',
      preferredCategories: (map['preferredCategories'] as List<dynamic>?)
              ?.map((e) => PoiCategory.values.firstWhere(
                    (c) => c.name == e,
                    orElse: () => PoiCategory.park,
                  ))
              .toList() ??
          [],
      avoidCategories: (map['avoidCategories'] as List<dynamic>?)
              ?.map((e) => PoiCategory.values.firstWhere(
                    (c) => c.name == e,
                    orElse: () => PoiCategory.park,
                  ))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetDistance': targetDistance,
      'routeType': routeType,
      'preferredCategories': preferredCategories.map((c) => c.name).toList(),
      'avoidCategories': avoidCategories.map((c) => c.name).toList(),
    };
  }

  UserPreferences copyWith({
    double? targetDistance,
    String? routeType,
    List<PoiCategory>? preferredCategories,
    List<PoiCategory>? avoidCategories,
  }) {
    return UserPreferences(
      targetDistance: targetDistance ?? this.targetDistance,
      routeType: routeType ?? this.routeType,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      avoidCategories: avoidCategories ?? this.avoidCategories,
    );
  }
}
