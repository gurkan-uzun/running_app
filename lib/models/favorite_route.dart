import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// A saved favorite route that can be reused
class FavoriteRoute {
  final String? id;
  final String name;
  final List<LatLng> points;
  final double distanceKm;
  final int estimatedMinutes;
  final int poiCount;
  final String routeType; // "Balanced", "Discovery", "Scenic", "Custom"
  final DateTime createdAt;
  final int timesUsed;

  FavoriteRoute({
    this.id,
    required this.name,
    required this.points,
    required this.distanceKm,
    this.estimatedMinutes = 0,
    this.poiCount = 0,
    this.routeType = 'Custom',
    DateTime? createdAt,
    this.timesUsed = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FavoriteRoute.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse route points
    List<LatLng> points = [];
    if (data['points'] != null) {
      for (var point in data['points']) {
        points.add(LatLng(
          (point['lat'] ?? 0).toDouble(),
          (point['lon'] ?? 0).toDouble(),
        ));
      }
    }
    
    return FavoriteRoute(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Route',
      points: points,
      distanceKm: (data['distanceKm'] ?? 0).toDouble(),
      estimatedMinutes: data['estimatedMinutes'] ?? 0,
      poiCount: data['poiCount'] ?? 0,
      routeType: data['routeType'] ?? 'Custom',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timesUsed: data['timesUsed'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'points': points.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
      'distanceKm': distanceKm,
      'estimatedMinutes': estimatedMinutes,
      'poiCount': poiCount,
      'routeType': routeType,
      'createdAt': Timestamp.fromDate(createdAt),
      'timesUsed': timesUsed,
    };
  }
}
