import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:running_app/services/overpass_service.dart';
import 'package:running_app/services/route_api_service.dart';
import 'package:running_app/services/database_service.dart';
import 'package:running_app/models/poi.dart';
import 'package:running_app/models/user_preferences.dart';
import 'package:running_app/models/generated_route.dart';
import 'package:running_app/models/favorite_route.dart';
import 'package:running_app/widgets/route_selector.dart';
import 'package:running_app/services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'run_tracking_screen.dart';

/// Main route generation screen - refactored from map_test_screen
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final MapController _mapController = MapController();
  final OverpassService _overpassService = OverpassService();
  final RouteApiService _routeApiService = RouteApiService();
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();
  
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<Poi> _currentPois = [];
  List<LatLng> _currentRoutePoints = [];
  
  bool _isGraphReady = false;
  bool _isLoading = false;
  bool _discoveryMode = true;
  Set<String> _visitedPoiIds = {};
  
  List<GeneratedRoute> _routeOptions = [];
  GeneratedRoute? _selectedRoute;
  bool _showRouteSelector = false;

  // Default center (can be updated by user location)
  LatLng _center = const LatLng(40.990, 29.020); // Kadikoy

  @override
  void initState() {
    super.initState();
    _initializeGraph();
  }

  Future<void> _initializeGraph() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final health = await _routeApiService.healthCheck();
      if (!mounted) return;
      if (health['status'] == 'ok' && health['graph_loaded'] == true) {
        setState(() {
          _isGraphReady = true;
          _isLoading = false;
        });
        // Auto-fetch POIs after graph is ready
        _fetchPois();
      } else {
        setState(() => _isLoading = false);
        _showError('Backend not ready. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Cannot connect to backend: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _fetchPois() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    final bounds = _mapController.camera.visibleBounds;
    double centerLat = bounds.center.latitude;
    double centerLon = bounds.center.longitude;
    
    List<Poi> pois = await _overpassService.fetchPois(centerLat, centerLon, 1000);
    
    // Load preferences and filter
    UserPreferences prefs = UserPreferences();
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        prefs = await _dbService.getPreferences();
        _visitedPoiIds = await _dbService.getVisitedPoiIds();
      }
    } catch (e) {
      print('Could not load preferences: $e');
    }
    
    // Filter POIs by preferences
    List<Poi> filteredPois = pois.where((poi) {
      if (prefs.avoidCategories.contains(poi.category)) return false;
      if (prefs.preferredCategories.isNotEmpty && 
          !prefs.preferredCategories.contains(poi.category)) return false;
      return true;
    }).toList();
    
    // Limit POIs for display to prevent clutter
    const int maxDisplayPois = 25;
    List<Poi> displayPois = filteredPois;
    if (filteredPois.length > maxDisplayPois) {
      displayPois = _selectDistributedPois(filteredPois, _mapController.camera.center, maxDisplayPois);
    }
    
    // Create markers for display
    List<Marker> markers = [];
    for (var poi in displayPois) {
      markers.add(Marker(
        point: LatLng(poi.lat, poi.lon),
        width: 35,
        height: 35,
        child: GestureDetector(
          onTap: () => _showPoiDetails(poi),
          child: Icon(
            Icons.location_on, 
            color: _getCategoryColor(poi.category), 
            size: 28,
          ),
        ),
      ));
    }
    
    if (!mounted) return;
    setState(() {
      _markers = markers;
      _currentPois = filteredPois; // Keep full list for route generation
      _isLoading = false;
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
  
  /// Select well-distributed POIs for display
  List<Poi> _selectDistributedPois(List<Poi> allPois, LatLng center, int maxCount) {
    if (allPois.length <= maxCount) return allPois;
    
    // Group by category for diversity
    Map<PoiCategory, List<Poi>> byCategory = {};
    for (var poi in allPois) {
      byCategory.putIfAbsent(poi.category, () => []).add(poi);
    }
    
    // Sort POIs within each category by distance from center
    for (var category in byCategory.keys) {
      byCategory[category]!.sort((a, b) {
        double distA = _distanceBetween(center.latitude, center.longitude, a.lat, a.lon);
        double distB = _distanceBetween(center.latitude, center.longitude, b.lat, b.lon);
        return distA.compareTo(distB);
      });
    }
    
    // Round-robin selection from categories
    List<Poi> selected = [];
    int perCategory = (maxCount / byCategory.length).ceil();
    
    for (var pois in byCategory.values) {
      selected.addAll(pois.take(perCategory.clamp(1, pois.length)));
    }
    
    return selected.take(maxCount).toList();
  }
  
  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
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
                    _getCategoryIcon(poi.category),
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
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
  
  IconData _getCategoryIcon(PoiCategory category) {
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

  Future<void> _generateRoutes() async {
    if (!_isGraphReady) {
      _showError('Please wait for backend to initialize');
      return;
    }
    
    if (_currentPois.isEmpty) {
      _showError('No POIs found. Move the map and try again.');
      return;
    }
    
    setState(() => _isLoading = true);
    
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
    LatLng startPoint;
    try {
      final gpsLocation = await _locationService.getCurrentLocation();
      if (gpsLocation == null) throw Exception('No GPS location');
      startPoint = gpsLocation;
      _center = startPoint; // Update center to user location
    } catch (e) {
      // Fall back to map center if GPS fails
      startPoint = _mapController.camera.center;
      print("GPS unavailable, using map center: $e");
    }
    
    double maxPoiDistance = targetDistanceMeters / 3;
    
    // Calculate distances for all POIs
    List<MapEntry<Poi, double>> allPoisWithDistance = _currentPois.map((poi) {
      double dist = _calculateDistance(startPoint.latitude, startPoint.longitude, poi.lat, poi.lon);
      return MapEntry(poi, dist);
    }).where((e) => e.value <= maxPoiDistance && e.value >= 50).toList();
    
    // If too few POIs, expand search radius
    if (allPoisWithDistance.length < 3) {
      allPoisWithDistance = _currentPois.map((poi) {
        double dist = _calculateDistance(startPoint.latitude, startPoint.longitude, poi.lat, poi.lon);
        return MapEntry(poi, dist);
      }).where((e) => e.value <= targetDistanceMeters && e.value >= 50).toList();
    }
    
    // Still not enough? Show helpful error
    if (allPoisWithDistance.isEmpty) {
      setState(() => _isLoading = false);
      _showError('No POIs found nearby. Try moving closer to points of interest or refresh POIs.');
      return;
    }
    
    List<GeneratedRoute> routes = [];
    
    // Route A: Balanced
    var balancedPois = _selectBalancedPois(allPoisWithDistance, 10);
    var routeA = await _generateSingleRoute('A', 'Balanced', balancedPois, startPoint, targetDistanceMeters);
    if (routeA != null) routes.add(routeA);
    
    // Route B: Discovery
    var discoveryPois = _selectDiscoveryPois(allPoisWithDistance, 10);
    var routeB = await _generateSingleRoute('B', 'Discovery', discoveryPois, startPoint, targetDistanceMeters);
    if (routeB != null) routes.add(routeB);
    
    // Route C: Scenic
    var scenicPois = _selectScenicPois(allPoisWithDistance, 10);
    var routeC = await _generateSingleRoute('C', 'Scenic', scenicPois, startPoint, targetDistanceMeters);
    if (routeC != null) routes.add(routeC);
    
    setState(() => _isLoading = false);
    
    if (routes.isEmpty) {
      _showError('Could not generate routes');
      return;
    }
    
    setState(() {
      _routeOptions = routes;
      _selectedRoute = routes.first;
      _showRouteSelector = true;
      _displayRoute(_selectedRoute!);
    });
  }
  
  List<Poi> _selectBalancedPois(List<MapEntry<Poi, double>> poisWithDistance, int maxCount) {
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
    var unvisited = poisWithDistance.where((e) => !_visitedPoiIds.contains(e.key.id.toString())).toList();
    var visited = poisWithDistance.where((e) => _visitedPoiIds.contains(e.key.id.toString())).toList();
    List<Poi> selected = [];
    selected.addAll(unvisited.map((e) => e.key));
    selected.addAll(visited.map((e) => e.key));
    return selected.take(maxCount).toList();
  }
  
  List<Poi> _selectScenicPois(List<MapEntry<Poi, double>> poisWithDistance, int maxCount) {
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
  
  Future<GeneratedRoute?> _generateSingleRoute(String id, String name, List<Poi> pois, LatLng start, double targetDistance) async {
    if (pois.isEmpty) return null;
    
    try {
      List<LatLng> poiCoords = pois.map((poi) => LatLng(poi.lat, poi.lon)).toList();
      final result = await _routeApiService.optimizeRoute(start: start, pois: poiCoords, targetDistanceMeters: targetDistance);
      List<LatLng> route = result.route;
      if (route.isEmpty) return null;
      
      double totalDistance = 0;
      for (int i = 0; i < route.length - 1; i++) {
        totalDistance += _calculateDistance(route[i].latitude, route[i].longitude, route[i + 1].latitude, route[i + 1].longitude);
      }
      
      return GeneratedRoute(id: id, name: name, description: '', points: route, distanceKm: totalDistance / 1000, pois: pois);
    } catch (e) {
      print("Error generating route $id: $e");
      return null;
    }
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    double dLat = (lat2 - lat1) * math.pi / 180;
    double dLon = (lon2 - lon1) * math.pi / 180;
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.asin(math.sqrt(a));
    return R * c;
  }
  
  void _displayRoute(GeneratedRoute route) {
    setState(() {
      _currentRoutePoints = route.points;
      _polylines = [
        Polyline(
          points: route.points,
          strokeWidth: 5.0,
          color: route.id == 'A' ? Colors.blue : route.id == 'B' ? Colors.green : Colors.orange,
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
  
  Future<void> _onSaveFavorite(GeneratedRoute route) async {
    final controller = TextEditingController(text: '${route.name} Route');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Route'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Route Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
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
          SnackBar(content: Text('Saved "$name" to favorites!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError('Error saving route: $e');
    }
  }
  
  void _startRun() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15.0,
              onMapEvent: (event) {
                // Could auto-fetch POIs on map move
              },
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
          
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Icon(_isGraphReady ? Icons.check_circle : Icons.hourglass_empty, 
                             color: _isGraphReady ? Colors.green : Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(_isGraphReady ? '${_currentPois.length} POIs' : 'Loading...'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Discovery mode toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Discovery', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: _discoveryMode,
                          onChanged: (v) => setState(() => _discoveryMode = v),
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
          
          // Generate routes button
          if (!_showRouteSelector)
            Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // Refresh POIs button
                  FloatingActionButton(
                    heroTag: 'refresh',
                    onPressed: _fetchPois,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.refresh, color: Colors.black),
                  ),
                  const Spacer(),
                  // Generate routes button
                  ElevatedButton.icon(
                    onPressed: _isGraphReady ? _generateRoutes : null,
                    icon: const Icon(Icons.route),
                    label: const Text('Generate Routes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Route selector bottom sheet
      bottomSheet: _showRouteSelector ? RouteSelector(
        routes: _routeOptions,
        selectedRoute: _selectedRoute,
        onRouteSelected: _onRouteSelected,
        onGenerateMore: () {
          setState(() => _showRouteSelector = false);
          _generateRoutes();
        },
        onStartRun: _startRun,
        onSaveFavorite: _onSaveFavorite,
      ) : null,
    );
  }
}
