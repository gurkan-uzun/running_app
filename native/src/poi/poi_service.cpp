#include "poi_service.h"
#include <stdio.h>

PoiService::PoiService() : provider(nullptr) {
}

PoiService::~PoiService() {
}

void PoiService::setProvider(IPoiProvider* provider) {
    this->provider = provider;
}

std::vector<Poi> PoiService::getPois(double lat, double lon, double radius) {
    if (this->provider == nullptr) {
        printf("Error: No POI provider set.\n");
        return std::vector<Poi>();
    }
    return this->provider->fetchPois(lat, lon, radius);
}
