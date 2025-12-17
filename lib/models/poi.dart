class Poi {
  final int id;
  final double lat;
  final double lon;
  final String name;
  final String category;
  final double rating; // Overpass might not give rating, simple default 0.0

  Poi({
    required this.id,
    required this.lat,
    required this.lon,
    required this.name,
    required this.category,
    this.rating = 0.0,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['id'] as int,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      name: json['tags']?['name'] ?? 'Unknown',
      category: _determineCategory(json['tags']),
    );
  }

  static String _determineCategory(Map<String, dynamic>? tags) {
    if (tags == null) return 'unknown';
    if (tags.containsKey('amenity')) return tags['amenity'];
    if (tags.containsKey('tourism')) return tags['tourism'];
    if (tags.containsKey('leisure')) return tags['leisure'];
    return 'other';
  }

  @override
  String toString() {
    return 'Poi{id: $id, name: $name, category: $category, lat: $lat, lon: $lon}';
  }
}
