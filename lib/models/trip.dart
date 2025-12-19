import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Represents a saved trip/route
class Trip {
  final String? id;
  final LatLng startPoint;
  final LatLng endPoint;
  final List<LatLng> routeCoords;
  final double distance; // in meters
  final int duration; // in seconds
  final List<String> visitedPoiIds;
  final DateTime createdAt;
  final int? rating; // 1-5

  Trip({
    this.id,
    required this.startPoint,
    required this.endPoint,
    required this.routeCoords,
    required this.distance,
    this.duration = 0,
    this.visitedPoiIds = const [],
    DateTime? createdAt,
    this.rating,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final startGeo = data['startPoint'] as GeoPoint;
    final endGeo = data['endPoint'] as GeoPoint;
    final coordsList = data['routeCoords'] as List<dynamic>;

    return Trip(
      id: doc.id,
      startPoint: LatLng(startGeo.latitude, startGeo.longitude),
      endPoint: LatLng(endGeo.latitude, endGeo.longitude),
      routeCoords: coordsList
          .map((g) => LatLng((g as GeoPoint).latitude, g.longitude))
          .toList(),
      distance: (data['distance'] ?? 0).toDouble(),
      duration: data['duration'] ?? 0,
      visitedPoiIds: List<String>.from(data['visitedPoiIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      rating: data['rating'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startPoint': GeoPoint(startPoint.latitude, startPoint.longitude),
      'endPoint': GeoPoint(endPoint.latitude, endPoint.longitude),
      'routeCoords': routeCoords
          .map((c) => GeoPoint(c.latitude, c.longitude))
          .toList(),
      'distance': distance,
      'duration': duration,
      'visitedPoiIds': visitedPoiIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'rating': rating,
    };
  }
}
