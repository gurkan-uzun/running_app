import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Backend REST API service for route optimization
/// Replaces native FFI service when using remote server
class BackendService {
  final String baseUrl;
  
  BackendService({this.baseUrl = 'http://localhost:8080'});
  
  /// Check server health and if graph is loaded
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'graph_loaded': false};
    } catch (e) {
      return {'status': 'error', 'error': e.toString(), 'graph_loaded': false};
    }
  }

  /// Initialize graph from OSM XML data
  Future<int> initGraph(String osmXmlData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/init-graph'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'osm_data': osmXmlData}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['nodes_count'] ?? 0;
        }
      }
      return -1;
    } catch (e) {
      print('BackendService.initGraph error: $e');
      return -1;
    }
  }

  /// Get route between two points (A to B)
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/get-route'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'start': {'lat': start.latitude, 'lon': start.longitude},
          'end': {'lat': end.latitude, 'lon': end.longitude},
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return _parseRoutePoints(data['route']);
        }
      }
      return [];
    } catch (e) {
      print('BackendService.getRoute error: $e');
      return [];
    }
  }

  /// Get optimized circular route visiting POIs
  Future<List<LatLng>> optimizeRoute({
    required LatLng start,
    required List<LatLng> pois,
    required double targetDistanceMeters,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/optimize-route'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'start': {'lat': start.latitude, 'lon': start.longitude},
          'target_distance_meters': targetDistanceMeters,
          'pois': pois.map((p) => {
            'lat': p.latitude,
            'lon': p.longitude,
            'prize': 1.0,
          }).toList(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return _parseRoutePoints(data['route']);
        }
      }
      return [];
    } catch (e) {
      print('BackendService.optimizeRoute error: $e');
      return [];
    }
  }

  /// Snap a single point to nearest walkable node
  Future<LatLng?> getNearestNode(double lat, double lon) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/nearest-node'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'lat': lat, 'lon': lon}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return LatLng(data['lat'], data['lon']);
        }
      }
      return null;
    } catch (e) {
      print('BackendService.getNearestNode error: $e');
      return null;
    }
  }

  /// BATCH: Snap multiple points to nearest walkable nodes in single request
  /// This replaces N individual API calls with 1 batch call
  Future<List<LatLng?>> getNearestNodesBatch(List<LatLng> points) async {
    if (points.isEmpty) return [];
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/nearest-nodes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'points': points.map((p) => {
            'lat': p.latitude,
            'lon': p.longitude,
          }).toList(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<LatLng?> results = [];
          for (var nodeResult in data['results']) {
            if (nodeResult['success'] == true) {
              results.add(LatLng(nodeResult['lat'], nodeResult['lon']));
            } else {
              // Return original point if snapping failed
              results.add(LatLng(nodeResult['lat'], nodeResult['lon']));
            }
          }
          return results;
        }
      }
      return List.filled(points.length, null);
    } catch (e) {
      print('BackendService.getNearestNodesBatch error: $e');
      return List.filled(points.length, null);
    }
  }

  List<LatLng> _parseRoutePoints(List<dynamic> routeData) {
    return routeData.map((point) => LatLng(
      (point['lat'] as num).toDouble(),
      (point['lon'] as num).toDouble(),
    )).toList();
  }
}
