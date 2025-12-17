#ifndef POI_SERVICE_H
#define POI_SERVICE_H

#include "poi_provider.h"
#include <vector>
#include <memory> /* for unique_ptr if we wanted, but raw ptr for now is fine per plan */

class PoiService {
public:
    PoiService();
    ~PoiService();

    void setProvider(IPoiProvider* provider);
    std::vector<Poi> getPois(double lat, double lon, double radius);

private:
    IPoiProvider* provider;
};

#endif // POI_SERVICE_H
