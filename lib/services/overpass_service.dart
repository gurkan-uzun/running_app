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
    // Fetch both nodes and ways (areas) - many POIs like beaches/parks are areas
    // Use 'out center' to get center point for ways
    final String query = '''
      [out:json][timeout:25];
      (
        node["amenity"](around:$radius,$lat,$lon);
        node["tourism"](around:$radius,$lat,$lon);
        node["leisure"](around:$radius,$lat,$lon);
        node["natural"](around:$radius,$lat,$lon);
        node["historic"](around:$radius,$lat,$lon);
        way["leisure"~"park|garden|playground"](around:$radius,$lat,$lon);
        way["natural"~"beach|wood|forest"](around:$radius,$lat,$lon);
        way["tourism"~"museum|attraction"](around:$radius,$lat,$lon);
      );
      out center;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'];
        
        return elements
            .where((e) {
              // Must have tags
              if (e['tags'] == null) return false;
              
              // For nodes, require lat/lon
              if (e['type'] == 'node') {
                return e['lat'] != null && e['lon'] != null;
              }
              
              // For ways, need center coordinates
              if (e['type'] == 'way') {
                return e['center'] != null;
              }
              
              return false;
            })
            .map((e) => _elementToPoi(e))
            .where((poi) => poi != null)
            .cast<Poi>()
            .toList();
      } else {
        print('Overpass API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching POIs: $e');
      return [];
    }
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
    // Overpass QL for all nodes and ways (standard map data)
    // (node(bbox);way(bbox);>;);out meta;
    final String query = '''
      [out:xml][timeout:90];
      (
        way($south,$west,$north,$east);
        >;
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
