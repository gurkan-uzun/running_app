#ifndef POI_H
#define POI_H

#include <string>

struct Poi {
    long id;
    double lat;
    double lon;
    std::string name;
    std::string category;
    double rating;
};

#endif // POI_H
