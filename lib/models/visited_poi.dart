import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a POI that the user has visited or rated
class VisitedPoi {
  final String poiId;
  final String poiName;
  final String poiCategory;
  final double lat;
  final double lon;
  final int visitCount;
  final DateTime lastVisited;
  final int? rating; // 1-5 stars, null if not rated
  final DateTime? ratedAt;

  VisitedPoi({
    required this.poiId,
    required this.poiName,
    required this.poiCategory,
    required this.lat,
    required this.lon,
    this.visitCount = 1,
    DateTime? lastVisited,
    this.rating,
    this.ratedAt,
  }) : lastVisited = lastVisited ?? DateTime.now();

  factory VisitedPoi.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitedPoi(
      poiId: doc.id,
      poiName: data['poiName'] ?? '',
      poiCategory: data['poiCategory'] ?? '',
      lat: (data['lat'] ?? 0).toDouble(),
      lon: (data['lon'] ?? 0).toDouble(),
      visitCount: data['visitCount'] ?? 1,
      lastVisited: (data['lastVisited'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rating: data['rating'],
      ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'poiName': poiName,
      'poiCategory': poiCategory,
      'lat': lat,
      'lon': lon,
      'visitCount': visitCount,
      'lastVisited': Timestamp.fromDate(lastVisited),
      if (rating != null) 'rating': rating,
      if (ratedAt != null) 'ratedAt': Timestamp.fromDate(ratedAt!),
    };
  }
}
