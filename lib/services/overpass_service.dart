import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/poi.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class OverpassService {
  final String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Poi>> fetchPois(double lat, double lon, double radius) async {
    // Retry with exponential backoff, reducing radius on server errors
    int maxRetries = 2;
    double currentRadius = radius;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final String query = '''
          [out:json][timeout:25];
          (
            node["amenity"](around:$currentRadius,$lat,$lon);
            node["tourism"](around:$currentRadius,$lat,$lon);
            node["leisure"](around:$currentRadius,$lat,$lon);
            node["natural"](around:$currentRadius,$lat,$lon);
            node["historic"](around:$currentRadius,$lat,$lon);
            way["leisure"~"park|garden|playground"](around:$currentRadius,$lat,$lon);
            way["natural"~"beach|wood|forest"](around:$currentRadius,$lat,$lon);
            way["tourism"~"museum|attraction"](around:$currentRadius,$lat,$lon);
          );
          out center;
        ''';

        final response = await http.post(
          Uri.parse(_overpassUrl),
          body: {'data': query},
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List<dynamic> elements = data['elements'];
          
          return elements
              .where((e) {
                if (e['tags'] == null) return false;
                if (e['type'] == 'node') {
                  return e['lat'] != null && e['lon'] != null;
                }
                if (e['type'] == 'way') {
                  return e['center'] != null;
                }
                return false;
              })
              .map((e) => _elementToPoi(e))
              .where((poi) => poi != null)
              .cast<Poi>()
              .toList();
        } else if ((response.statusCode == 504 || response.statusCode == 429) 
                   && attempt < maxRetries) {
          // Server overloaded — wait and retry with smaller radius
          print('Overpass ${response.statusCode}, retry ${attempt + 1} with radius ${(currentRadius * 0.7).toInt()}m');
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          currentRadius *= 0.7; // Reduce radius by 30%
          continue;
        } else {
          print('Overpass API Error: ${response.statusCode}');
          return [];
        }
      } catch (e) {
        if (attempt < maxRetries) {
          print('Overpass exception, retry ${attempt + 1}: $e');
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          currentRadius *= 0.7;
          continue;
        }
        print('Exception fetching POIs: $e');
        return [];
      }
    }
    
    return [];
  }
  
  Poi? _elementToPoi(Map<String, dynamic> e) {
    try {
      double lat, lon;
      
      if (e['type'] == 'node') {
        lat = (e['lat'] as num).toDouble();
        lon = (e['lon'] as num).toDouble();
      } else if (e['type'] == 'way' && e['center'] != null) {
        lat = (e['center']['lat'] as num).toDouble();
        lon = (e['center']['lon'] as num).toDouble();
      } else {
        return null;
      }
      
      // Generate a name for unnamed features
      final tags = e['tags'] as Map<String, dynamic>?;
      String name = tags?['name'] ?? _generateName(tags);
      
      return Poi.fromJson({
        'id': e['id'],
        'lat': lat,
        'lon': lon,
        'tags': {...?tags, 'name': name},
      });
    } catch (ex) {
      print('Error parsing POI: $ex');
      return null;
    }
  }
  
  String _generateName(Map<String, dynamic>? tags) {
    if (tags == null) return 'Unknown';
    
    // Generate descriptive name based on type
    if (tags['natural'] == 'beach') return 'Beach';
    if (tags['natural'] == 'wood') return 'Forest';
    if (tags['natural'] == 'forest') return 'Forest';
    if (tags['leisure'] == 'park') return 'Park';
    if (tags['leisure'] == 'garden') return 'Garden';
    if (tags['leisure'] == 'playground') return 'Playground';
    if (tags['tourism'] == 'viewpoint') return 'Viewpoint';
    if (tags['amenity'] != null) return tags['amenity'].toString().replaceAll('_', ' ').capitalize();
    if (tags['tourism'] != null) return tags['tourism'].toString().replaceAll('_', ' ').capitalize();
    
    return 'Unknown';
  }

  // Download raw OSM XML for a bounding box to a local file
  Future<String?> downloadMapData(double south, double west, double north, double east) async {
    // Overpass QL for:
    // 1. All ways (road network) 
    // 2. POI nodes (amenity, tourism, leisure, natural, historic)
    // The '>' recurses to get node refs for ways
    final String query = '''
      [out:xml][timeout:90];
      (
        way($south,$west,$north,$east);
        >;
        node["amenity"]($south,$west,$north,$east);
        node["tourism"]($south,$west,$north,$east);
        node["leisure"]($south,$west,$north,$east);
        node["natural"]($south,$west,$north,$east);
        node["historic"]($south,$west,$north,$east);
      );
      out meta;
    ''';

    try {
      print('Downloading OSM data for bbox: $south, $west, $north, $east');
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/map_data.osm');
        await file.writeAsBytes(response.bodyBytes);
        int size = await file.length();
        print('Downloaded Map Data: $size bytes to ${file.path}');
        return file.path;
      } else {
        print('Overpass Map Data Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception downloading map data: $e');
      return null;
    }
  }
}
