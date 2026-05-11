import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:running_app/services/overpass_service.dart';
import 'package:running_app/services/route_api_service.dart';
import 'package:running_app/services/database_service.dart';
import 'package:running_app/models/poi.dart';
import 'package:running_app/models/trip.dart';
import 'package:running_app/models/user_preferences.dart';
import 'package:running_app/models/generated_route.dart';
import 'package:running_app/models/favorite_route.dart';
import 'package:running_app/widgets/route_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_app/services/location_service.dart';
import 'run_tracking_screen.dart';

class MapTestScreen extends StatefulWidget {
  const MapTestScreen({super.key});

  @override
  State<MapTestScreen> createState() => _MapTestScreenState();
}

class _MapTestScreenState extends State<MapTestScreen> {
  final MapController _mapController = MapController();
  final OverpassService _overpassService = OverpassService();
  final RouteApiService _routeApiService = RouteApiService();
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();
  List<LatLng> _currentRoutePoints = [];

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<Poi> _currentPois = []; // Store current POIs for route optimization
  
  bool _isGraphReady = false;
  bool _discoveryMode = true; // Prefer unvisited POIs in route optimization
  Set<String> _visitedPoiIds = {}; // Loaded from Firestore
  String _status = "Ready";
  
  // User's current GPS location for route starting point
  LatLng? _userLocation;
  
  // Multi-route selection
  List<GeneratedRoute> _routeOptions = [];
  GeneratedRoute? _selectedRoute;
  bool _showRouteSelector = false;

  // Kadikoy, Istanbul (default center)
  final LatLng _center = const LatLng(40.990, 29.020);

  Future<void> _downloadAndInit() async {
    setState(() => _status = "Checking backend server...");
    
    // Check if backend is healthy
    final health = await _routeApiService.healthCheck();
    
    if (health['status'] == 'ok' && health['graph_loaded'] == true) {
      setState(() {
        _isGraphReady = true;
        _status = "Backend Ready: ${health['nodes_count']} nodes";
      });
      return;
    }
    
    // If graph not loaded, download and send OSM data
    setState(() => _status = "Downloading Map Data...");
    
    final bounds = _mapController.camera.visibleBounds;
    double south = bounds.south;
    double west = bounds.west;
    double north = bounds.north;
    double east = bounds.east;

    String? path = await _overpassService.downloadMapData(south, west, north, east);
    
    if (path != null) {
      setState(() => _status = "Sending to backend server...");
      try {
        File f = File(path);
        String xmlContent = await f.readAsString();
        
        final result = await _routeApiService.initGraph(xmlContent);
        
        if (result['success'] == true) {
             setState(() {
                _isGraphReady = true;
                _status = "Graph Loaded: ${result['nodes_count']} nodes";
             });
        } else {
             setState(() {
                _isGraphReady = false;
                _status = "Graph Init Failed: ${result['error']}";
             });
        }
      } catch (e) {
        setState(() => _status = "Error: $e");
      }
    } else {
      setState(() => _status = "Download Failed");
    }
  }

  Future<void> _fetchPois() async {
    setState(() => _status = "Fetching POIs from backend server...");
    
    final bounds = _mapController.camera.visibleBounds;
    // Calculate center of visible area
    double centerLat = bounds.center.latitude;
    double centerLon = bounds.center.longitude;
    
    // Calculate radius (approximate based on height)
    double radius = 1000; // Default 1km
    
    List<Poi> pois = [];
    
    // Try fetching from backend first (POIs are parsed during graph init)
    if (_isGraphReady) {
      setState(() => _status = "Fetching POIs from backend...");
      List<Map<String, dynamic>> backendPois = await _routeApiService.fetchPoisFromBackend(
        centerLat, centerLon, radius
      );
      
      if (backendPois.isNotEmpty) {
        // Convert backend JSON to Poi objects
        pois = backendPois.map((data) {
          // Map backend category to PoiCategory enum
          PoiCategory category = _mapBackendCategory(data['category'] as String? ?? 'other');
          
          return Poi(
            id: (data['id'] as num).toInt(),
            lat: (data['lat'] as num).toDouble(),
            lon: (data['lon'] as num).toDouble(),
            name: data['name'] as String? ?? 'Unknown',
            category: category,
            rawCategory: data['rawCategory'] as String? ?? '',
          );
        }).toList();
        
        print('Fetched ${pois.length} POIs from backend server');
      }
    }
    
    // Fallback to Overpass if backend has no POIs or graph not loaded
    if (pois.isEmpty) {
      setState(() => _status = "Backend has no POIs, falling back to Overpass...");
      pois = await _overpassService.fetchPois(centerLat, centerLon, radius);
      print('Fetched ${pois.length} POIs from Overpass API');
    }
    
    // Load user preferences and filter POIs
    UserPreferences prefs = UserPreferences();
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        prefs = await _dbService.getPreferences();
        // Load visited POI IDs for discovery mode
        _visitedPoiIds = await _dbService.getVisitedPoiIds();
      }
    } catch (e) {
      print('Could not load preferences: $e');
    }
    
    // Debug: Print preferences and category distribution
    print('=== POI Debug ===');
    print('Preferred categories: ${prefs.preferredCategories.map((c) => c.name).toList()}');
    print('Avoided categories: ${prefs.avoidCategories.map((c) => c.name).toList()}');
    
    // Count categories
    Map<PoiCategory, int> catCount = {};
    for (var poi in pois) {
      catCount[poi.category] = (catCount[poi.category] ?? 0) + 1;
    }
    print('Category distribution: ${catCount.map((k, v) => MapEntry(k.name, v))}');
    
    // Show beach POIs specifically
    var beaches = pois.where((p) => p.category == PoiCategory.beach).toList();
    print('Beach POIs found: ${beaches.length}');
    for (var b in beaches.take(5)) {
      print('  - ${b.name} (${b.rawCategory})');
    }
    
    // Filter POIs based on preferences
    List<Poi> filteredPois = pois.where((poi) => poi.matchesPreferences(prefs)).toList();
    
    print('Total: ${pois.length}, After filter: ${filteredPois.length}');
    
    // Limit POIs to prevent map clutter - keep well-distributed subset
    const int maxDisplayPois = 25;
    if (filteredPois.length > maxDisplayPois) {
      filteredPois = _selectDistributedPois(filteredPois, bounds.center, maxDisplayPois);
      print('Limited to $maxDisplayPois well-distributed POIs');
    }
    print('=================');
    
    // Snap area POIs to nearest walkable path if graph is loaded
    // Use BATCH API to reduce N calls to 1 call
    List<LatLng> displayPoints = filteredPois.map((p) => LatLng(p.lat, p.lon)).toList();
    
    if (_isGraphReady && filteredPois.isNotEmpty) {
      setState(() => _status = "Snapping ${filteredPois.length} POIs to walkable paths...");
      final snappedPoints = await _routeApiService.getNearestNodesBatch(displayPoints);
      for (int i = 0; i < displayPoints.length && i < snappedPoints.length; i++) {
        if (snappedPoints[i] != null) {
          displayPoints[i] = snappedPoints[i]!;
        }
      }
    }
    
    // Build markers with snapped positions
    List<Marker> markers = [];
    for (int i = 0; i < filteredPois.length; i++) {
      final poi = filteredPois[i];
      markers.add(Marker(
        point: displayPoints[i],
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showPoiDetails(poi),
          child: Icon(Icons.location_on, color: _getCategoryColor(poi.category), size: 30),
        ),
      ));
    }
    
    setState(() {
      _markers = markers;
      _status = "Found ${filteredPois.length} POIs (${pois.length} total, filtered by preferences)";
      _currentPois = filteredPois; // Store for route optimization
    });
  }
  
  Color _getCategoryColor(PoiCategory category) {
    switch (category) {
      case PoiCategory.park: return Colors.green;
      case PoiCategory.museum: return Colors.purple;
      case PoiCategory.viewpoint: return Colors.blue;
      case PoiCategory.cafe: return Colors.brown;
      case PoiCategory.restaurant: return Colors.orange;
      case PoiCategory.monument: return Colors.grey;
      case PoiCategory.nature: return Colors.teal;
      case PoiCategory.beach: return Colors.cyan;
      case PoiCategory.other: return Colors.red;
    }
  }
  
  /// Map backend category string to PoiCategory enum
  PoiCategory _mapBackendCategory(String category) {
    switch (category.toLowerCase()) {
      case 'park': return PoiCategory.park;
      case 'museum': return PoiCategory.museum;
      case 'viewpoint': return PoiCategory.viewpoint;
      case 'cafe': return PoiCategory.cafe;
      case 'restaurant': return PoiCategory.restaurant;
      case 'monument': return PoiCategory.monument;
      case 'nature': return PoiCategory.nature;
      case 'beach': return PoiCategory.beach;
      default: return PoiCategory.other;
    }
  }
  
  /// Select well-distributed POIs to prevent clustering
  /// Prioritizes category diversity and spatial spread
  List<Poi> _selectDistributedPois(List<Poi> allPois, LatLng center, int maxCount) {
    if (allPois.length <= maxCount) return allPois;
    
    // Group by category for diversity
    Map<PoiCategory, List<Poi>> byCategory = {};
    for (var poi in allPois) {
      byCategory.putIfAbsent(poi.category, () => []).add(poi);
    }
    
    // Sort POIs within each category by distance from center (farthest first for spread)
    for (var category in byCategory.keys) {
      byCategory[category]!.sort((a, b) {
        double distA = _distanceBetween(center.latitude, center.longitude, a.lat, a.lon);
        double distB = _distanceBetween(center.latitude, center.longitude, b.lat, b.lon);
        return distA.compareTo(distB); // Closer first
      });
    }
    
    // Round-robin selection from categories
    List<Poi> selected = [];
    int categoryCount = byCategory.length;
    int perCategory = (maxCount / categoryCount).ceil();
    
    for (var entry in byCategory.entries) {
      var pois = entry.value;
      int toTake = perCategory.clamp(1, pois.length);
      selected.addAll(pois.take(toTake));
    }
    
    return selected.take(maxCount).toList();
  }
  
  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    // Simplified distance calculation (Euclidean approximation)
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    return dLat * dLat + dLon * dLon;
  }

  void _showPoiDetails(Poi poi) {
    final bool isVisited = _visitedPoiIds.contains(poi.id.toString());
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(poi.category).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIconData(poi.category),
                      color: _getCategoryColor(poi.category),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poi.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          poi.categoryDisplayName,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (isVisited)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                          const SizedBox(width: 4),
                          Text('Visited', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Rating if available
              if (poi.rating > 0) ...[
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < poi.rating.round() ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${poi.rating.toStringAsFixed(1)} rating',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Location info
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[500], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${poi.lat.toStringAsFixed(5)}, ${poi.lon.toStringAsFixed(5)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _routeToPoi(poi);
                  },
                  icon: const Icon(Icons.directions_run),
                  label: const Text('Route To Here'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
  
  IconData _getCategoryIconData(PoiCategory category) {
    switch (category) {
      case PoiCategory.park: return Icons.park;
      case PoiCategory.museum: return Icons.museum;
      case PoiCategory.viewpoint: return Icons.visibility;
      case PoiCategory.cafe: return Icons.local_cafe;
      case PoiCategory.restaurant: return Icons.restaurant;
      case PoiCategory.monument: return Icons.account_balance;
      case PoiCategory.nature: return Icons.nature;
      case PoiCategory.beach: return Icons.beach_access;
      case PoiCategory.other: return Icons.place;
    }
  }

  Future<void> _routeToPoi(Poi targetPoi) async {
     if (!_isGraphReady) {
      setState(() => _status = "Graph not loaded!");
      return;
    }
    
    setState(() => _status = "Calculating Route to ${targetPoi.name}...");
    
    // Start from center (simulated user location)
    LatLng start = _center;
    LatLng end = LatLng(targetPoi.lat, targetPoi.lon);
    
    // Add start/end markers
    setState(() {
       // Keep POI markers but add flags
       _markers.add(Marker(point: start, width: 40, height: 40, child: const Icon(Icons.flag, color: Colors.green)));
       _markers.add(Marker(point: end, width: 40, height: 40, child: const Icon(Icons.flag, color: Colors.blue)));
    });

    try {
      List<LatLng> routePoints = await _routeApiService.getRoute(start, end);
      
      if (routePoints.isNotEmpty) {
        setState(() {
          _polylines = [
            Polyline(points: routePoints, strokeWidth: 4.0, color: Colors.blue)
          ];
          _status = "Route Found (${routePoints.length} points)";
        });
      } else {
        setState(() => _status = "No Route Found");
      }
    } catch (e) {
      setState(() => _status = "Routing Error: $e");
    }
  }

  Future<void> _calculateRoute() async {
    if (!_isGraphReady) {
      setState(() => _status = "Graph not loaded!");
      return;
    }

    if (_selectedStart == null || _selectedEnd == null) {
      setState(() => _status = "Please select Start and End points");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tap map to set Start and End points")));
      return;
    }
    
    setState(() => _status = "Calculating Route...");
    
    // Use selected points
    LatLng start = _selectedStart!;
    LatLng end = _selectedEnd!;
    
    try {
      List<LatLng> routePoints = await _routeApiService.getRoute(start, end);
      
      if (routePoints.length >= 2) {
        setState(() {
          _status = "Route Found (${routePoints.length} points)";
          _currentRoutePoints = routePoints; // Store for saving
          _polylines = [
              Polyline(points: routePoints, strokeWidth: 4.0, color: Colors.blue)
          ];
        });
      } else if (routePoints.isNotEmpty) {
         // Found only start point?
         setState(() => _status = "Route too short (points: ${routePoints.length}). Start/End snapped to same node?");
      } else {
        setState(() => _status = "No Route Found");
      }
    } catch (e) {
      print(e);
      setState(() => _status = "Error: $e");
    }
  }

  LatLng? _selectedStart;
  LatLng? _selectedEnd;

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 150,
          child: Column(
            children: [
              Text("Location: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}"),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStart = point;
                        // Start point marker
                        _markers.removeWhere((m) => m.key == const Key("start_marker"));
                        _markers.add(Marker(
                          key: const Key("start_marker"),
                          point: point,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.flag, color: Colors.green, size: 30),
                        ));
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("Set Start"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedEnd = point;
                        // End point marker
                        _markers.removeWhere((m) => m.key == const Key("end_marker"));
                        _markers.add(Marker(
                          key: const Key("end_marker"),
                          point: point,
                          width: 40, 
                          height: 40,
                          child: const Icon(Icons.flag, color: Colors.blue, size: 30),
                        ));
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text("Set End"),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveTrip() async {
    if (_currentRoutePoints.isEmpty || _selectedStart == null || _selectedEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No route to save")),
      );
      return;
    }

    // Check if user is logged in
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to save trips")),
      );
      return;
    }

    setState(() => _status = "Saving trip...");

    try {
      // Calculate distance
      double totalDistance = 0;
      for (int i = 0; i < _currentRoutePoints.length - 1; i++) {
        final p1 = _currentRoutePoints[i];
        final p2 = _currentRoutePoints[i + 1];
        // Simple distance calculation (Haversine would be more accurate)
        totalDistance += _calculateDistance(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
      }

      final trip = Trip(
        startPoint: _selectedStart!,
        endPoint: _selectedEnd!,
        routeCoords: _currentRoutePoints,
        distance: totalDistance,
      );

      await _dbService.saveTrip(trip);

      setState(() {
        _status = "Trip saved! (${(totalDistance / 1000).toStringAsFixed(2)} km)";
        _currentRoutePoints = []; // Clear after saving
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trip saved: ${(totalDistance / 1000).toStringAsFixed(2)} km")),
      );
    } catch (e) {
      setState(() => _status = "Save failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save trip: $e"), backgroundColor: Colors.red),
      );
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula
    const double R = 6371000; // Earth radius in meters
    double dLat = (lat2 - lat1) * math.pi / 180;
    double dLon = (lon2 - lon1) * math.pi / 180;
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * 
        math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.asin(math.sqrt(a));
    return R * c;
  }


  Future<void> _showNativeLogs() async {
    try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/native_debug.log");
        if (await file.exists()) {
             String content = await file.readAsString();
             // Show in dialog
             if (!mounted) return;
             showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text("Native Logs"),
                content: SingleChildScrollView(child: Text(content)),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
             ));
        } else {
             if (!mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No log file found")));
        }
    } catch (e) {
        print("Error reading log: $e");
    }
  }

  Future<void> _generateOptimizedRoute() async {
    if (!_isGraphReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please load the graph first!")),
      );
      return;
    }
    
    if (_currentPois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fetch POIs first!")),
      );
      return;
    }
    
    setState(() => _status = "Generating route options...");
    
    // Get target distance from preferences (default 5km = 5000m)
    double targetDistanceMeters = 5000;
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        final prefs = await _dbService.getPreferences();
        targetDistanceMeters = prefs.targetDistance * 1000;
      }
    } catch (e) {
      print("Could not load preferences: $e");
    }
    
    // Get user's current GPS location for route start
    // Falls back to map center if GPS unavailable
    LatLng startPoint;
    try {
      final gpsLocation = await _locationService.getCurrentLocation();
      if (gpsLocation == null) throw Exception('No GPS location');
      startPoint = gpsLocation;
      _userLocation = gpsLocation;
      setState(() => _status = "Starting route from your location...");
    } catch (e) {
      // Fall back to map center if GPS fails
      startPoint = _mapController.camera.center;
      print("GPS unavailable, using map center: $e");
    }
    
    double maxPoiDistance = targetDistanceMeters / 3;
    
    // Calculate distance for each POI
    List<MapEntry<Poi, double>> allPoisWithDistance = _currentPois.map((poi) {
      double dist = _calculateDistance(startPoint.latitude, startPoint.longitude, poi.lat, poi.lon);
      return MapEntry(poi, dist);
    }).where((e) => e.value <= maxPoiDistance && e.value >= 100)
    .toList();
    
    // Generate 3 route variants
    List<GeneratedRoute> routes = [];
    
    // Route A: Balanced - mix of all categories
    var balancedPois = _selectBalancedPois(allPoisWithDistance, 10);
    var routeA = await _generateSingleRoute(
      id: 'A',
      name: 'Balanced',
      description: 'Mix of all POI types',
      pois: balancedPois,
      start: startPoint,
      targetDistance: targetDistanceMeters,
    );
    if (routeA != null) routes.add(routeA);
    
    // Route B: Discovery - prioritize unvisited POIs
    var discoveryPois = _selectDiscoveryPois(allPoisWithDistance, 10);
    var routeB = await _generateSingleRoute(
      id: 'B',
      name: 'Discovery',
      description: 'Explore new places',
      pois: discoveryPois,
      start: startPoint,
      targetDistance: targetDistanceMeters,
    );
    if (routeB != null) routes.add(routeB);
    
    // Route C: Scenic - prioritize parks and nature
    var scenicPois = _selectScenicPois(allPoisWithDistance, 10);
    var routeC = await _generateSingleRoute(
      id: 'C',
      name: 'Scenic',
      description: 'Parks and nature',
      pois: scenicPois,
      start: startPoint,
      targetDistance: targetDistanceMeters,
    );
    if (routeC != null) routes.add(routeC);
    
    if (routes.isEmpty) {
      setState(() => _status = "No routes found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not generate any routes")),
      );
      return;
    }
    
    setState(() {
      _routeOptions = routes;
      _selectedRoute = routes.first;
      _showRouteSelector = true;
      _status = "Generated ${routes.length} route options";
      // Show first route on map
      _displayRoute(_selectedRoute!);
    });
  }
  
  List<Poi> _selectBalancedPois(List<MapEntry<Poi, double>> poisWithDistance, int maxCount) {
    // Group by category and take from each
    Map<PoiCategory, List<Poi>> byCategory = {};
    for (var e in poisWithDistance) {
      byCategory.putIfAbsent(e.key.category, () => []).add(e.key);
    }
    
    List<Poi> selected = [];
    int perCategory = (maxCount / byCategory.length).ceil();
    for (var pois in byCategory.values) {
      selected.addAll(pois.take(perCategory));
    }
    return selected.take(maxCount).toList();
  }
  
  List<Poi> _selectDiscoveryPois(List<MapEntry<Poi, double>> poisWithDistance, int maxCount) {
    // Prioritize unvisited POIs
    var unvisited = poisWithDistance.where(
      (e) => !_visitedPoiIds.contains(e.key.id.toString())
    ).toList();
    var visited = poisWithDistance.where(
      (e) => _visitedPoiIds.contains(e.key.id.toString())
    ).toList();
    
    List<Poi> selected = [];
    selected.addAll(unvisited.map((e) => e.key));
    selected.addAll(visited.map((e) => e.key));
    return selected.take(maxCount).toList();
  }
  
  List<Poi> _selectScenicPois(List<MapEntry<Poi, double>> poisWithDistance, int maxCount) {
    // Prioritize parks, nature, viewpoints, beach
    var scenic = poisWithDistance.where((e) => 
      e.key.category == PoiCategory.park ||
      e.key.category == PoiCategory.nature ||
      e.key.category == PoiCategory.viewpoint ||
      e.key.category == PoiCategory.beach
    ).toList();
    var others = poisWithDistance.where((e) => 
      e.key.category != PoiCategory.park &&
      e.key.category != PoiCategory.nature &&
      e.key.category != PoiCategory.viewpoint &&
      e.key.category != PoiCategory.beach
    ).toList();
    
    List<Poi> selected = [];
    selected.addAll(scenic.map((e) => e.key));
    selected.addAll(others.map((e) => e.key));
    return selected.take(maxCount).toList();
  }
  
  Future<GeneratedRoute?> _generateSingleRoute({
    required String id,
    required String name,
    required String description,
    required List<Poi> pois,
    required LatLng start,
    required double targetDistance,
  }) async {
    if (pois.isEmpty) return null;
    
    try {
      List<LatLng> poiCoords = pois.map((poi) => LatLng(poi.lat, poi.lon)).toList();
      
      final result = await _routeApiService.optimizeRoute(
        start: start,
        pois: poiCoords,
        targetDistanceMeters: targetDistance,
      );
      
      List<LatLng> route = result.route;
      if (route.isEmpty) return null;
      
      // Calculate distance
      double totalDistance = 0;
      for (int i = 0; i < route.length - 1; i++) {
        totalDistance += _calculateDistance(
          route[i].latitude, route[i].longitude,
          route[i + 1].latitude, route[i + 1].longitude,
        );
      }
      
      return GeneratedRoute(
        id: id,
        name: name,
        description: description,
        points: route,
        distanceKm: totalDistance / 1000,
        pois: pois,
      );
    } catch (e) {
      print("Error generating route $id: $e");
      return null;
    }
  }
  
  void _displayRoute(GeneratedRoute route) {
    setState(() {
      _currentRoutePoints = route.points;
      _polylines = [
        Polyline(
          points: route.points,
          strokeWidth: 5.0,
          color: route.id == 'A' ? Colors.blue : 
                 route.id == 'B' ? Colors.green : Colors.orange,
        ),
      ];
    });
  }
  
  void _onRouteSelected(GeneratedRoute route) {
    setState(() {
      _selectedRoute = route;
      _displayRoute(route);
    });
  }
  
  void _onStartRunFromSelector() {
    if (_selectedRoute == null) return;
    
    setState(() => _showRouteSelector = false);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RunTrackingScreen(
          plannedRoute: _selectedRoute!.points,
          pois: _selectedRoute!.pois,
        ),
      ),
    );
  }

  void _startRun() {
    // Navigate to run tracking screen
    // Pass current route as planned route if available
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RunTrackingScreen(
          plannedRoute: _currentRoutePoints.isNotEmpty ? _currentRoutePoints : null,
          pois: _currentPois.isNotEmpty ? _currentPois : null,
        ),
      ),
    );
  }
  
  Future<void> _onSaveFavorite(GeneratedRoute route) async {
    // Prompt for route name
    final controller = TextEditingController(text: '${route.name} Route');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Route'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Route Name',
            hintText: 'My favorite route',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (name == null || name.isEmpty) return;
    
    try {
      final favoriteRoute = FavoriteRoute(
        name: name,
        points: route.points,
        distanceKm: route.distanceKm,
        estimatedMinutes: route.estimatedTimeMinutes,
        poiCount: route.pois.length,
        routeType: route.name,
      );
      
      await _dbService.saveFavoriteRoute(favoriteRoute);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$name" to favorites!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("WP4 Integration Test")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            // 1. Wrap the Row in a SingleChildScrollView
            child: SingleChildScrollView(
              // 2. Set the direction to horizontal so it scrolls sideways
              scrollDirection: Axis.horizontal, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("Status: $_status"),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Text('Discovery'),
                      Switch(
                        value: _discoveryMode,
                        onChanged: (val) => setState(() => _discoveryMode = val),
                        activeThumbColor: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 15.0,
                onTap: _handleMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.running_app',
                ),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _downloadAndInit,
                  child: const Text("1. Load Graph"),
                ),
                ElevatedButton(
                  onPressed: _fetchPois,
                  child: const Text("2. POIs"),
                ),
                 ElevatedButton(
                  onPressed: _calculateRoute,
                  child: const Text("3. Route"),
                ),
                ElevatedButton(
                  onPressed: _currentRoutePoints.isNotEmpty ? _saveTrip : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("4. Save"),
                ),
                ElevatedButton(
                  onPressed: _showNativeLogs,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                  child: const Text("Logs"),
                ),
                ElevatedButton(
                  onPressed: _isGraphReady && _currentPois.isNotEmpty ? _generateOptimizedRoute : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  child: const Text("5. Optimize"),
                ),
                ElevatedButton(
                  onPressed: () => _startRun(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text("6. Run"),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
      // Route selector overlay
      bottomSheet: _showRouteSelector ? RouteSelector(
        routes: _routeOptions,
        selectedRoute: _selectedRoute,
        onRouteSelected: _onRouteSelected,
        onGenerateMore: () {
          setState(() => _showRouteSelector = false);
          _generateOptimizedRoute();
        },
        onStartRun: _onStartRunFromSelector,
        onSaveFavorite: _onSaveFavorite,
      ) : null,
    );
  }
}
