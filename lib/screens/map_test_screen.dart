import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:running_app/services/overpass_service.dart';
import 'package:running_app/services/native_service.dart';
import 'package:running_app/models/poi.dart';
import 'package:path_provider/path_provider.dart';

class MapTestScreen extends StatefulWidget {
  const MapTestScreen({super.key});

  @override
  State<MapTestScreen> createState() => _MapTestScreenState();
}

class _MapTestScreenState extends State<MapTestScreen> {
  final MapController _mapController = MapController();
  final OverpassService _overpassService = OverpassService();
  final NativeService _nativeService = NativeService();

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  
  bool _isGraphReady = false;
  String _status = "Ready";

  // Kadikoy, Istanbul
  final LatLng _center = const LatLng(40.990, 29.020);

  Future<void> _downloadAndInit() async {
    setState(() => _status = "Downloading Map Data...");
    
    // Get visible bounds or use a fixed small area around center
    // Ideally we use _mapController.camera.visibleBounds but let's use fixed small box for reliability first
    // 1km box
    // Get visible bounds
    final bounds = _mapController.camera.visibleBounds;
    double south = bounds.south;
    double west = bounds.west;
    double north = bounds.north;
    double east = bounds.east;

    String? path = await _overpassService.downloadMapData(south, west, north, east);
    
    if (path != null) {
      setState(() => _status = "Reading Map File...");
      try {
        File f = File(path);
        String xmlContent = await f.readAsString();
        
        setState(() => _status = "Initializing C++ Graph...");
        int nodeCount = await _nativeService.initGraph(xmlContent);
        
        if (nodeCount > 0) {
             setState(() {
                _isGraphReady = true;
                _status = "Graph Loaded: $nodeCount nodes";
             });
        } else {
             // Get detailed error
             String error = _nativeService.getLastError();
             setState(() {
                _isGraphReady = false;
                _status = "Graph Init Failed: $error";
             });
        }
      } catch (e) {
        setState(() => _status = "File Read Error: $e");
      }
    } else {
      setState(() => _status = "Download Failed");
    }
  }

  Future<void> _fetchPois() async {
    setState(() => _status = "Fetching POIs for visible area...");
    
    final bounds = _mapController.camera.visibleBounds;
    // Calculate center of visible area
    double centerLat = bounds.center.latitude;
    double centerLon = bounds.center.longitude;
    
    // Calculate radius (approximate based on height)
    double radius = 1000; // Default
    
    List<Poi> pois = await _overpassService.fetchPois(centerLat, centerLon, radius);
    
    setState(() {
      _markers = pois.map((poi) => Marker(
        point: LatLng(poi.lat, poi.lon),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showPoiDetails(poi),
          child: const Icon(Icons.location_on, color: Colors.red, size: 30),
        ),
      )).toList();
      _status = "Found ${pois.length} POIs in visible area";
    });
  }

  void _showPoiDetails(Poi poi) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(poi.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Category: ${poi.category}"),
              Text("Location: ${poi.lat.toStringAsFixed(4)}, ${poi.lon.toStringAsFixed(4)}"),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    _routeToPoi(poi);
                  },
                  icon: const Icon(Icons.directions_run),
                  label: const Text("Route To Here"),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      List<LatLng> routePoints = await _nativeService.getRoute(start, end);
      
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
      List<LatLng> routePoints = await _nativeService.getRoute(start, end);
      
      if (routePoints.length >= 2) {
        setState(() => _status = "Route Found (${routePoints.length} points)");
        _polylines = [
            Polyline(points: routePoints, strokeWidth: 4.0, color: Colors.blue)
        ];
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
                  onPressed: _showNativeLogs,
                  child: const Text("Logs"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}
