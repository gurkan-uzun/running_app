#ifndef POI_PROVIDER_H
#define POI_PROVIDER_H

#include "poi.h"
#include <vector>

class IPoiProvider {
public:
    virtual ~IPoiProvider() {}
    
    // Fetch POIs within a radius (meters) of a center point
    virtual std::vector<Poi> fetchPois(double lat, double lon, double radius) = 0;
};

#endif // POI_PROVIDER_H
