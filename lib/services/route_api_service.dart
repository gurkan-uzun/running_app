import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';

/// API Service for route optimization
/// Replaces FFI-based NativeService with HTTP calls to the backend server
class RouteApiService {
  
  /// Check if the backend is healthy and graph is loaded
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.health}'),
      ).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }
  
  /// Initialize graph with OSM XML data
  Future<Map<String, dynamic>> initGraph(String osmXmlData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.initGraph}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'osm_data': osmXmlData}),
      ).timeout(ApiConfig.optimizeTimeout);
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Get simple A-to-B route
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getRoute}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start': {'lat': start.latitude, 'lon': start.longitude},
          'end': {'lat': end.latitude, 'lon': end.longitude},
        }),
      ).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['route'] != null) {
          return (data['route'] as List)
              .map((p) => LatLng(p['lat'], p['lon']))
              .toList();
        }
      }
      print('getRoute error: ${response.body}');
      return [];
    } catch (e) {
      print('getRoute exception: $e');
      return [];
    }
  }
  
  /// Optimize multi-POI circular route
  Future<RouteResult> optimizeRoute({
    required LatLng start,
    required List<LatLng> pois,
    required double targetDistanceMeters,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.optimizeRoute}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start': {'lat': start.latitude, 'lon': start.longitude},
          'pois': pois.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
          'target_distance_meters': targetDistanceMeters,
        }),
      ).timeout(ApiConfig.optimizeTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['route'] != null) {
          return RouteResult(
            route: (data['route'] as List)
                .map((p) => LatLng(p['lat'], p['lon']))
                .toList(),
            totalDistanceMeters: (data['total_distance_meters'] ?? 0).toDouble(),
            poisVisited: data['pois_visited'] ?? 0,
          );
        }
      }
      print('optimizeRoute error: ${response.body}');
      return RouteResult.empty();
    } catch (e) {
      print('optimizeRoute exception: $e');
      return RouteResult.empty();
    }
  }
  
  /// Find nearest walkable node (snap to graph)
  Future<LatLng?> getNearestNode(double lat, double lon) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.nearestNode}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lat': lat, 'lon': lon}),
      ).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return LatLng(data['lat'], data['lon']);
        }
      }
      return null;
    } catch (e) {
      print('getNearestNode exception: $e');
      return null;
    }
  }
  
  /// BATCH: Snap multiple points to nearest walkable nodes in a single request
  /// Reduces N individual API calls to 1 batch call - critical for remote servers
  Future<List<LatLng?>> getNearestNodesBatch(List<LatLng> points) async {
    if (points.isEmpty) return [];
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.nearestNodesBatch}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'points': points.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
        }),
      ).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['results'] != null) {
          List<LatLng?> results = [];
          for (var nodeResult in data['results']) {
            if (nodeResult['success'] == true) {
              results.add(LatLng(nodeResult['lat'], nodeResult['lon']));
            } else {
              results.add(null); // Snapping failed for this point
            }
          }
          return results;
        }
      }
      return List.filled(points.length, null);
    } catch (e) {
      print('getNearestNodesBatch exception: $e');
      return List.filled(points.length, null);
    }
  }
  
  /// Fetch POIs from the backend server within a radius of the given center
  /// This replaces the Overpass API call with backend-provided POI data
  Future<List<Map<String, dynamic>>> fetchPoisFromBackend(double lat, double lon, double radius) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pois}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
          'radius': radius,
        }),
      ).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['pois'] != null) {
          return List<Map<String, dynamic>>.from(data['pois']);
        }
      }
      print('fetchPoisFromBackend error: ${response.body}');
      return [];
    } catch (e) {
      print('fetchPoisFromBackend exception: $e');
      return [];
    }
  }
}

/// Result from route optimization
class RouteResult {
  final List<LatLng> route;
  final double totalDistanceMeters;
  final int poisVisited;
  
  RouteResult({
    required this.route,
    required this.totalDistanceMeters,
    required this.poisVisited,
  });
  
  factory RouteResult.empty() => RouteResult(
    route: [],
    totalDistanceMeters: 0,
    poisVisited: 0,
  );
  
  bool get isEmpty => route.isEmpty;
  bool get isNotEmpty => route.isNotEmpty;
}
