import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/database_service.dart';
import '../models/trip.dart';
import '../models/favorite_route.dart';
import 'run_tracking_screen.dart';

/// Saved page showing run history and favorite routes
class SavedPage extends StatelessWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Saved",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "My Runs"),
              Tab(text: "Routes"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyRunsTab(),
            _FavoriteRoutesTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: MY RUNS
// ---------------------------------------------------------------------------
class _MyRunsTab extends StatefulWidget {
  const _MyRunsTab();

  @override
  State<_MyRunsTab> createState() => _MyRunsTabState();
}

class _MyRunsTabState extends State<_MyRunsTab> {
  final DatabaseService _dbService = DatabaseService();
  List<Trip> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await _dbService.getTrips();
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading trips: $e');
    }
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${secs}s';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _showFullRouteMap(Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatDate(trip.createdAt)} - ${(trip.distance / 1000).toStringAsFixed(2)} km',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(trip.routeCoords),
                        padding: const EdgeInsets.all(30),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.running_app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: trip.routeCoords,
                            strokeWidth: 5,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: trip.startPoint,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.play_circle, color: Colors.green, size: 30),
                          ),
                          Marker(
                            point: trip.endPoint,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.flag_circle, color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_run, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No runs yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a run to see it here!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return _buildTripCard(trip);
        },
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 150,
              child: trip.routeCoords.isNotEmpty 
                ? GestureDetector(
                    onTap: () => _showFullRouteMap(trip),
                    child: FlutterMap(
                      options: _getSafeMapOptions(trip.routeCoords),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.running_app',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: trip.routeCoords,
                              strokeWidth: 4,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.map, size: 48, color: Colors.grey[400]),
                    ),
                  ),
            ),
          ),
          // Trip details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(trip.createdAt),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(trip.distance / 1000).toStringAsFixed(2)} km',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip(Icons.timer, _formatDuration(trip.duration)),
                    const SizedBox(width: 16),
                    _buildStatChip(
                      Icons.speed,
                      trip.distance > 0 && trip.duration > 0
                          ? '${((trip.duration / 60) / (trip.distance / 1000)).toStringAsFixed(1)} min/km'
                          : '--',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }
  MapOptions _getSafeMapOptions(List<LatLng> points) {
    if (points.length < 2) {
      return MapOptions(
        initialCenter: points.isNotEmpty ? points.first : const LatLng(0, 0),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      );
    }
    
    final bounds = LatLngBounds.fromPoints(points);
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
       return MapOptions(
        initialCenter: bounds.center,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      );
    }

    return MapOptions(
      initialCameraFit: CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(20),
      ),
      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: FAVORITE ROUTES
// ---------------------------------------------------------------------------
class _FavoriteRoutesTab extends StatefulWidget {
  const _FavoriteRoutesTab();

  @override
  State<_FavoriteRoutesTab> createState() => _FavoriteRoutesTabState();
}

class _FavoriteRoutesTabState extends State<_FavoriteRoutesTab> {
  final DatabaseService _dbService = DatabaseService();
  List<FavoriteRoute> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await _dbService.getFavoriteRoutes();
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading routes: $e');
    }
  }

  Future<void> _deleteRoute(FavoriteRoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text('Delete "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true && route.id != null) {
      await _dbService.deleteFavoriteRoute(route.id!);
      _loadRoutes();
    }
  }
  
  /// Start a run with this saved route as the planned route
  void _startRun(FavoriteRoute route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RunTrackingScreen(
          plannedRoute: route.points,
        ),
      ),
    );
  }
  
  void _showFullFavoriteRouteMap(FavoriteRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          route.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    options: _getSafeMapOptions(route.points),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.running_app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.points,
                            strokeWidth: 5,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No saved routes',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Save a route when generating to see it here!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];
          return _buildRouteCard(route);
        },
      ),
    );
  }

  Widget _buildRouteCard(FavoriteRoute route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 120,
              child: route.points.isNotEmpty 
                ? GestureDetector(
                    onTap: () => _showFullFavoriteRouteMap(route),
                    child: FlutterMap(
                      options: _getSafeMapOptions(route.points),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.running_app',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: route.points,
                              strokeWidth: 4,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.map, size: 48, color: Colors.grey[400]),
                    ),
                  ),
            ),
          ),
          // Route details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildChip(Icons.straighten, '${route.distanceKm.toStringAsFixed(1)} km'),
                          const SizedBox(width: 12),
                          _buildChip(Icons.timer, '~${route.estimatedMinutes} min'),
                          const SizedBox(width: 12),
                          _buildChip(Icons.place, '${route.poiCount} POIs'),
                        ],
                      ),
                    ],
                  ),
                ),
                // Start Run button
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 32),
                  tooltip: 'Start Run',
                  onPressed: () => _startRun(route),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _deleteRoute(route),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
  MapOptions _getSafeMapOptions(List<LatLng> points) {
    if (points.length < 2) {
      return MapOptions(
        initialCenter: points.isNotEmpty ? points.first : const LatLng(0, 0),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      );
    }
    
    final bounds = LatLngBounds.fromPoints(points);
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
       return MapOptions(
        initialCenter: bounds.center,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      );
    }

    return MapOptions(
      initialCameraFit: CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(20),
      ),
      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
    );
  }
}
