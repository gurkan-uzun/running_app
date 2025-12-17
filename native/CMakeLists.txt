cmake_minimum_required(VERSION 3.4.1)

project(running_app_backend)

set(CMAKE_CXX_STANDARD 14)

add_library( # Sets the name of the library.
             running_app_backend

             # Sets the library as a shared library.
             SHARED

             # Provides a relative path to your source file(s).
             src/running_app.cpp
             src/osm/osm_parser.cpp
             src/tinyxml2.cpp
             src/dijkstra.cpp
             src/poi/poi_service.cpp
             src/poi/mock_poi_provider.cpp )

include_directories(include)

find_library( # Sets the name of the path variable.
              log-lib

              # Specifies the name of the NDK library that
              # you want CMake to locate.
              log )

target_link_libraries( # Specifies the target library.
                       running_app_backend

                       # Links the target library to the log library
                       # included in the NDK.
                       ${log-lib} )
