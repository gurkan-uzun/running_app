import 'package:running_app/services/overpass_service.dart';
import 'package:running_app/models/poi.dart';

void main() async {
  final service = OverpassService();
  
  // Test coordinates: Kadikoy, Istanbul directly from memory or approximate
  // Lat: 40.9901, Lon: 29.0206
  print('Fetching POIs for Kadikoy...');
  
  try {
    List<Poi> pois = await service.fetchPois(40.990, 29.020, 500);
    print('Found ${pois.length} POIs.');
    
    for (var poi in pois.take(5)) {
      print(poi);
    }
  } catch (e) {
    print('Error: $e');
  }
}
