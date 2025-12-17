#ifndef MOCK_POI_PROVIDER_H
#define MOCK_POI_PROVIDER_H

#include "poi_provider.h"

class MockPoiProvider : public IPoiProvider {
public:
    std::vector<Poi> fetchPois(double lat, double lon, double radius) override;
};

#endif // MOCK_POI_PROVIDER_H
