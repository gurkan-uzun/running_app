import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/poi.dart';

class OverpassService {
  final String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Poi>> fetchPois(double lat, double lon, double radius) async {
    // Overpass QL query:
    // [out:json];
    // (
    //   node["amenity"](around:radius,lat,lon);
    //   node["tourism"](around:radius,lat,lon);
    //   node["leisure"](around:radius,lat,lon);
    // );
    // out body;
    
    final String query = '''
      [out:json][timeout:25];
      (
        node["amenity"](around:$radius,$lat,$lon);
        node["tourism"](around:$radius,$lat,$lon);
        node["leisure"](around:$radius,$lat,$lon);
      );
      out body;
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
            .where((e) => e['type'] == 'node' && e['tags'] != null && e['tags']['name'] != null)
            .map((e) => Poi.fromJson(e))
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
