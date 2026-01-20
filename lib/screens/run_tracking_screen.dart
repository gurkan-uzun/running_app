import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../models/trip.dart';
import '../models/poi.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class RunTrackingScreen extends StatefulWidget {
  final List<LatLng>? plannedRoute;
  final List<Poi>? pois; // POIs along the route for visit tracking
  
  const RunTrackingScreen({super.key, this.plannedRoute, this.pois});

  @override
  State<RunTrackingScreen> createState() => _RunTrackingScreenState();
}

class _RunTrackingScreenState extends State<RunTrackingScreen> {
  final LocationService _locationService = LocationService();
  final DatabaseService _dbService = DatabaseService();
  final MapController _mapController = MapController();
  
  // Run state
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  
  // Location tracking
  StreamSubscription? _locationSubscription;
  LatLng? _currentLocation;
  List<LatLng> _runPath = [];
  double _totalDistance = 0;
  double _currentSpeed = 0;
  String _currentPace = '--:--';
  
  // Navigation state for planned route
  int _currentWaypointIndex = 0;
  double _distanceToNextWaypoint = 0;
  double _distanceRemainingOnRoute = 0;
  String _navigationInstruction = '';
  
  // POI visit tracking
  Set<int> _visitedPoiIds = {}; // POIs visited during this run
  List<Poi> _poisToRate = []; // POIs to rate after run completes
  static const double _poiProximityThreshold = 50.0; // meters
  
  @override
  void initState() {
    super.initState();
    _initLocation();
    _calculateInitialRouteDistance();
  }
  
  void _calculateInitialRouteDistance() {
    if (widget.plannedRoute != null && widget.plannedRoute!.length > 1) {
      double total = 0;
      for (int i = 0; i < widget.plannedRoute!.length - 1; i++) {
        total += _calculateDistance(widget.plannedRoute![i], widget.plannedRoute![i + 1]);
      }
      setState(() {
        _distanceRemainingOnRoute = total;
      });
    }
  }
  
  double _calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude, from.longitude,
      to.latitude, to.longitude,
    );
  }
  
  Future<void> _initLocation() async {
    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')),
        );
      }
      return;
    }
    
    final location = await _locationService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() => _currentLocation = location);
      _updateNavigation(location);
      _mapController.move(location, 16);
    }
  }
  
  void _updateNavigation(LatLng currentPos) {
    if (widget.plannedRoute == null || widget.plannedRoute!.isEmpty) return;
    
    // Find nearest waypoint on route
    int nearestIndex = _currentWaypointIndex;
    double minDist = double.infinity;
    
    // Look ahead a bit to find the best next waypoint
    for (int i = _currentWaypointIndex; i < widget.plannedRoute!.length && i < _currentWaypointIndex + 10; i++) {
      double dist = _calculateDistance(currentPos, widget.plannedRoute![i]);
      if (dist < minDist) {
        minDist = dist;
        nearestIndex = i;
      }
    }
    
    // If we're close to a waypoint, advance to next
    if (nearestIndex < widget.plannedRoute!.length - 1 && minDist < 30) {
      nearestIndex++;
    }
    
    // Calculate distance to next waypoint
    double distToNext = 0;
    if (nearestIndex < widget.plannedRoute!.length) {
      distToNext = _calculateDistance(currentPos, widget.plannedRoute![nearestIndex]);
    }
    
    // Calculate remaining distance on route
    double remaining = distToNext;
    for (int i = nearestIndex; i < widget.plannedRoute!.length - 1; i++) {
      remaining += _calculateDistance(widget.plannedRoute![i], widget.plannedRoute![i + 1]);
    }
    
    // Generate navigation instruction
    String instruction = _generateInstruction(currentPos, nearestIndex);
    
    setState(() {
      _currentWaypointIndex = nearestIndex;
      _distanceToNextWaypoint = distToNext;
      _distanceRemainingOnRoute = remaining;
      _navigationInstruction = instruction;
    });
  }
  
  String _generateInstruction(LatLng currentPos, int nextIndex) {
    if (widget.plannedRoute == null || nextIndex >= widget.plannedRoute!.length) {
      return "Follow the route";
    }
    
    LatLng nextPoint = widget.plannedRoute![nextIndex];
    double bearing = _calculateBearing(currentPos, nextPoint);
    String direction = _bearingToDirection(bearing);
    
    if (_distanceToNextWaypoint > 100) {
      return "Continue $direction for ${(_distanceToNextWaypoint / 1000).toStringAsFixed(1)}km";
    } else if (nextIndex >= widget.plannedRoute!.length - 1) {
      return "Arriving at destination";
    } else {
      return "Head $direction";
    }
  }
  
  double _calculateBearing(LatLng from, LatLng to) {
    double lat1 = from.latitude * math.pi / 180;
    double lat2 = to.latitude * math.pi / 180;
    double dLon = (to.longitude - from.longitude) * math.pi / 180;
    
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - 
               math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    
    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }
  
  String _bearingToDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return "North";
    if (bearing >= 22.5 && bearing < 67.5) return "Northeast";
    if (bearing >= 67.5 && bearing < 112.5) return "East";
    if (bearing >= 112.5 && bearing < 157.5) return "Southeast";
    if (bearing >= 157.5 && bearing < 202.5) return "South";
    if (bearing >= 202.5 && bearing < 247.5) return "Southwest";
    if (bearing >= 247.5 && bearing < 292.5) return "West";
    return "Northwest";
  }
  
  void _startRun() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _runPath = [];
      _totalDistance = 0;
      _currentWaypointIndex = 0;
      if (_currentLocation != null) {
        _runPath.add(_currentLocation!);
      }
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
    
    _locationSubscription = _locationService.startTracking().listen((update) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_runPath.isNotEmpty) {
            _totalDistance += _locationService.calculateDistance(
              _runPath.last, update.location
            );
          }
          _runPath.add(update.location);
          _currentLocation = update.location;
          _currentSpeed = update.speed;
          _currentPace = update.paceMinPerKm;
        });
        
        // Update navigation
        _updateNavigation(update.location);
        
        // Check if near any POIs
        _checkPoiProximity(update.location);
        
        _mapController.move(update.location, _mapController.camera.zoom);
      }
    });
  }
  
  void _pauseRun() {
    setState(() => _isPaused = true);
  }
  
  void _resumeRun() {
    setState(() => _isPaused = false);
  }
  
  /// Check if user is near any POIs and mark them as visited
  void _checkPoiProximity(LatLng currentPos) {
    if (widget.pois == null || widget.pois!.isEmpty) return;
    
    for (var poi in widget.pois!) {
      // Skip if already visited during this run
      if (_visitedPoiIds.contains(poi.id)) continue;
      
      double distance = _calculateDistance(
        currentPos, 
        LatLng(poi.lat, poi.lon)
      );
      
      if (distance < _poiProximityThreshold) {
        // Mark as visited
        setState(() {
          _visitedPoiIds.add(poi.id);
          _poisToRate.add(poi);
        });
        
        // Save to database
        _dbService.markPoiVisited(
          poiId: poi.id.toString(),
          poiName: poi.name,
          poiCategory: poi.category.name,
          lat: poi.lat,
          lon: poi.lon,
        );
        
        // Show notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Visited: ${poi.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Future<void> _stopRun() async {
    _timer?.cancel();
    _locationService.stopTracking();
    _locationSubscription?.cancel();
    
    if (_runPath.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run too short to save')),
      );
      setState(() {
        _isRunning = false;
        _isPaused = false;
      });
      return;
    }
    
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Run?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${(_totalDistance / 1000).toStringAsFixed(2)} km'),
            Text('Time: ${_formatDuration(_elapsedTime)}'),
            Text('Avg Pace: ${_calculateAvgPace()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (shouldSave == true) {
      await _saveRun();
      // Show rating dialog if POIs were visited
      if (_poisToRate.isNotEmpty) {
        await _showRatingDialog();
      }
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _visitedPoiIds.clear();
      _poisToRate.clear();
    });
  }
  
  Future<void> _saveRun() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final trip = Trip(
        startPoint: _runPath.first,
        endPoint: _runPath.last,
        routeCoords: _runPath,
        distance: _totalDistance,
        duration: _elapsedTime.inSeconds,
        createdAt: _startTime ?? DateTime.now(),
      );
      
      await _dbService.saveTrip(trip);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Run saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  /// Show dialog to rate visited POIs
  Future<void> _showRatingDialog() async {
    for (var poi in _poisToRate) {
      final rating = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PoiRatingDialog(poiName: poi.name),
      );
      
      if (rating != null && rating > 0) {
        await _dbService.ratePoi(poi.id.toString(), rating);
      }
    }
  }
  
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }
  
  String _calculateAvgPace() {
    if (_totalDistance < 100) return '--:--';
    double minPerKm = (_elapsedTime.inSeconds / 60) / (_totalDistance / 1000);
    int mins = minPerKm.floor();
    int secs = ((minPerKm - mins) * 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} /km';
  }
  
  // Split planned route into completed (gray) and remaining (blue)
  List<LatLng> get _completedRoute {
    if (widget.plannedRoute == null || _currentWaypointIndex <= 0) return [];
    return widget.plannedRoute!.sublist(0, _currentWaypointIndex + 1);
  }
  
  List<LatLng> get _remainingRoute {
    if (widget.plannedRoute == null || _currentWaypointIndex >= widget.plannedRoute!.length - 1) {
      return widget.plannedRoute ?? [];
    }
    return widget.plannedRoute!.sublist(_currentWaypointIndex);
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _locationService.stopTracking();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRunning ? 'Running...' : 'Start Run'),
        backgroundColor: _isRunning ? Colors.green : null,
      ),
      body: Column(
        children: [
          // Navigation instruction banner
          if (widget.plannedRoute != null && widget.plannedRoute!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.blue[700],
              child: Row(
                children: [
                  const Icon(Icons.navigation, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _navigationInstruction.isEmpty ? 'Follow the route' : _navigationInstruction,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Next: ${(_distanceToNextWaypoint).toStringAsFixed(0)}m • Remaining: ${(_distanceRemainingOnRoute / 1000).toStringAsFixed(1)}km',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Stats panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statWidget('TIME', _formatDuration(_elapsedTime)),
                _statWidget('DISTANCE', '${(_totalDistance / 1000).toStringAsFixed(2)} km'),
                _statWidget('PACE', _currentPace),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? const LatLng(40.990, 29.020),
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.running_app',
                ),
                
                // Completed part of planned route (GRAY - already visited)
                if (_completedRoute.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _completedRoute,
                        strokeWidth: 6,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                
                // Remaining part of planned route (BLUE - to visit)
                if (_remainingRoute.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _remainingRoute,
                        strokeWidth: 6,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                
                // Actual run path (GREEN)
                if (_runPath.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _runPath,
                        strokeWidth: 5,
                        color: Colors.green,
                      ),
                    ],
                  ),
                
                // Next waypoint marker
                if (widget.plannedRoute != null && 
                    _currentWaypointIndex < widget.plannedRoute!.length)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.plannedRoute![_currentWaypointIndex],
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Current location marker
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Control buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: _buildControlButtons(),
          ),
        ],
      ),
    );
  }
  
  Widget _statWidget(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildControlButtons() {
    if (!_isRunning) {
      return ElevatedButton(
        onPressed: _startRun,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: const Size(200, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: const Text('START RUN', style: TextStyle(fontSize: 20, color: Colors.white)),
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _isPaused ? _resumeRun : _pauseRun,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isPaused ? Colors.green : Colors.orange,
            minimumSize: const Size(120, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(
            _isPaused ? 'RESUME' : 'PAUSE',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
        const SizedBox(width: 20),
        ElevatedButton(
          onPressed: _stopRun,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            minimumSize: const Size(120, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('STOP', style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ],
    );
  }
}

/// Star rating dialog for POIs
class _PoiRatingDialog extends StatefulWidget {
  final String poiName;
  
  const _PoiRatingDialog({required this.poiName});

  @override
  State<_PoiRatingDialog> createState() => _PoiRatingDialogState();
}

class _PoiRatingDialogState extends State<_PoiRatingDialog> {
  int _selectedRating = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.poiName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How was this place?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                icon: Icon(
                  starIndex <= _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
                onPressed: () {
                  setState(() => _selectedRating = starIndex);
                },
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 0), // Skip rating
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _selectedRating > 0 
              ? () => Navigator.pop(context, _selectedRating)
              : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
