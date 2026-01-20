import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service for GPS location tracking
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  
  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  /// Get current location once
  Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;
      
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  /// Start continuous location tracking
  /// Returns a stream of location updates
  Stream<LocationUpdate> startTracking() {
    final controller = StreamController<LocationUpdate>.broadcast();
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      controller.add(LocationUpdate(
        location: LatLng(position.latitude, position.longitude),
        speed: position.speed, // meters per second
        altitude: position.altitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      ));
    }, onError: (e) {
      print('Location stream error: $e');
    });
    
    return controller.stream;
  }
  
  /// Stop tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
  
  /// Calculate distance between two points (Haversine formula)
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude, from.longitude,
      to.latitude, to.longitude,
    );
  }
}

/// Location update data
class LocationUpdate {
  final LatLng location;
  final double speed; // m/s
  final double altitude; // meters
  final double accuracy; // meters
  final DateTime timestamp;
  
  LocationUpdate({
    required this.location,
    required this.speed,
    required this.altitude,
    required this.accuracy,
    required this.timestamp,
  });
  
  /// Speed in km/h
  double get speedKmh => speed * 3.6;
  
  /// Pace in min/km (if moving)
  String get paceMinPerKm {
    if (speed < 0.5) return '--:--'; // Not moving
    double minPerKm = 1000 / speed / 60;
    int mins = minPerKm.floor();
    int secs = ((minPerKm - mins) * 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
