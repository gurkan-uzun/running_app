#include "mock_poi_provider.h"
#include <vector>

std::vector<Poi> MockPoiProvider::fetchPois(double lat, double lon, double radius) {
    std::vector<Poi> pois;
    
    // Return some dummy POIs around the center
    pois.push_back({1, lat + 0.001, lon + 0.001, "Mock Cafe", "cafe", 4.5});
    pois.push_back({2, lat - 0.001, lon - 0.001, "Mock Park", "park", 5.0});
    pois.push_back({3, lat + 0.002, lon - 0.002, "Mock Museum", "museum", 4.2});
    
    return pois;
}
