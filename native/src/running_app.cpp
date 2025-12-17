#include <stdint.h>
#include <stdio.h>
#include <vector>
#include "osm_parser.h"
#include "graph.h"
#include "dijkstra.h"
#include "nearest_neighbor.h"
#include "poi_service.h"
#include "mock_poi_provider.h"

#include <stdarg.h>

// Log callback type definition
typedef void (*LogCallback)(const char* message);

// Global State
// Global State
Graph g_graph;
bool g_isGraphLoaded = false;
char g_lastError[256] = "No error";
LogCallback g_logCallback = nullptr;
char g_logFilePath[1024] = {0};

// Helper log function
void native_log(const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    // 1. Print to stdout (backup)
    printf("%s\n", buffer);
    fflush(stdout);

    // 2. Call callback if registered
    if (g_logCallback) {
        g_logCallback(buffer);
    }

    // 3. Write to File if path set
    if (g_logFilePath[0] != '\0') {
        FILE* f = fopen(g_logFilePath, "a");
        if (f) {
            fprintf(f, "%s\n", buffer);
            fclose(f);
        }
    }
}

void set_error(const char* msg) {
    strncpy(g_lastError, msg, 255);
    g_lastError[255] = '\0';
    native_log("Native Error Set: %s", g_lastError);
}

#ifdef __cplusplus
extern "C" {
#endif

// Initialize logging with a file path
void init_logging(char* logPath) {
    if (logPath) {
        strncpy(g_logFilePath, logPath, 1023);
        g_logFilePath[1023] = '\0';
        
        // Clear old log
        FILE* f = fopen(g_logFilePath, "w");
        if (f) {
            fprintf(f, "--- Native Log Started ---\n");
            fclose(f);
        }
        native_log("Native: Logging initialized to file: %s", g_logFilePath);
    }
}

// Register a callback for logging
void register_log_callback(LogCallback callback) {
    g_logCallback = callback;
    native_log("Native: Log callback registered.");
}

// Get the last error message
void get_last_error(char* buffer, int32_t length) {
    strncpy(buffer, g_lastError, length);
    buffer[length - 1] = '\0';
}

// Initialize the graph from XML content string
int32_t init_graph(char* xmlData) {
    if (xmlData == NULL) {
        set_error("XML Data is NULL");
        return -1;
    }
    printf("Native: Initializing graph from XML string (Length: %lu)\n", std::string(xmlData).length());
    
    g_graph = Graph(); // Clear existing
    OsmParser parser;
    int result = parser.parseString(xmlData, g_graph, g_lastError, 256);
    
    if (result == 0) {
        g_isGraphLoaded = true;
        set_error("None"); // Clear error
        native_log("Native: Graph loaded with %lu nodes and %lu adjacency entries.", 
                   g_graph.nodes.size(), g_graph.adjacency_list.size());
        return (int32_t)g_graph.nodes.size();
    } else {
        // parser.parseString should have printed the error, but let's capture a generic one if not set
        // Actually we need to capture the specific error from parser.
        // For now, let's set a generic one if result is -1, but ideally parser sets it.
        // Since we can't easily modify parser signature without more refactoring, 
        // we'll rely on parseString's return code mapping or let parser write to a global? 
        // Let's just set a generic one here, and catch specific ones inside parseString if possible.
        // But running_app.cpp doesn't know the exact tinyxml error.
        // We will modify parseString to return positive int on error? No.
        
        // Let's just set a fallback error here.
        if (strcmp(g_lastError, "No error") == 0 || strcmp(g_lastError, "None") == 0) {
             set_error("Unknown Error during parsing (Check logs)");
        }
        return -1;
    }
}
// Find shortest path and fill the output buffer with [lat, lon, lat, lon...]
// Returns the number of points in the path, or -1 on error.
int32_t get_route(double startLat, double startLon, double endLat, double endLon, double* outCoords, int32_t maxCapacity) {
    if (!g_isGraphLoaded) {
        printf("Native Error: Graph not loaded.\n");
        return -1;
    }

    // 1. Find start and end nodes
    native_log("Native: Finding nearest nodes for Start(%.6f, %.6f) and End(%.6f, %.6f)", startLat, startLon, endLat, endLon);
    int64_t startNodeId = NearestNeighbor::findNearestNode(g_graph, startLat, startLon);
    int64_t endNodeId = NearestNeighbor::findNearestNode(g_graph, endLat, endLon);

    if (startNodeId == -1 || endNodeId == -1) {
        native_log("Native Error: Could not find nearest nodes (StartID: %lld, EndID: %lld).", startNodeId, endNodeId);
        return -1;
    }
    
    native_log("Native: Routing from Node %lld to %lld", startNodeId, endNodeId);
    
    // Diagnostic: Check if nodes have edges
    size_t startEdges = 0, endEdges = 0;
    if (g_graph.adjacency_list.find(startNodeId) != g_graph.adjacency_list.end()) {
        startEdges = g_graph.adjacency_list[startNodeId].size();
    }
    if (g_graph.adjacency_list.find(endNodeId) != g_graph.adjacency_list.end()) {
        endEdges = g_graph.adjacency_list[endNodeId].size();
    }
    native_log("Native: Start node has %lu edges, End node has %lu edges", startEdges, endEdges);
    
    // Print actual neighbor IDs for debugging
    if (startEdges > 0 && startEdges <= 10) {
        native_log("Native: Start node neighbors:");
        for (const auto& edge : g_graph.adjacency_list[startNodeId]) {
            native_log("  -> Node %lld (dist: %.2fm)", edge.targetNodeId, edge.weight);
        }
    }
    
    // Check for nearby nodes that might be at same intersection but different ID
    Node& startNode = g_graph.nodes[startNodeId];
    int nearbyCount = 0;
    for (const auto& pair : g_graph.adjacency_list) {
        if (pair.first == startNodeId) continue;
        Node& other = g_graph.nodes[pair.first];
        double dLat = startNode.lat - other.lat;
        double dLon = startNode.lon - other.lon;
        double distSq = dLat * dLat + dLon * dLon;
        // Check for nodes within ~10m (approx 0.0001 degrees)
        if (distSq < 0.0001 * 0.0001) {
            nearbyCount++;
            if (nearbyCount <= 5) {
                native_log("Native: Nearby connected node %lld at (%.6f, %.6f) with %lu edges", 
                           pair.first, other.lat, other.lon, pair.second.size());
            }
        }
    }
    if (nearbyCount > 0) {
        native_log("Native: Found %d other connected nodes very close to start node!", nearbyCount);
    }

    // 2. Run Dijkstra
    Dijkstra dijkstra;
    std::vector<int64_t> path = dijkstra.findShortestPath(g_graph, startNodeId, endNodeId);
    
    if (path.empty()) {
        native_log("Native: No path found between %lld and %lld.", startNodeId, endNodeId);
        return 0;
    }

    native_log("Native: Path found with %lu nodes. Converting to coordinates...", path.size());

    // 3. Fill Output Buffer
    int32_t pointsCount = 0;
    for (int64_t nodeId : path) {
        if (pointsCount * 2 + 1 >= maxCapacity) {
             native_log("Native Warning: Buffer full (Capacity: %d). Truncating path.", maxCapacity);
             break; 
        }
        
        if (g_graph.nodes.find(nodeId) != g_graph.nodes.end()) {
            Node& n = g_graph.nodes[nodeId];
            outCoords[pointsCount * 2] = n.lat;
            outCoords[pointsCount * 2 + 1] = n.lon;
            pointsCount++;
        } else {
            native_log("Native Error: Node %lld in path not found in graph!", nodeId);
        }
    }
    
    native_log("Native: Returning path with %d points.", pointsCount);
    return pointsCount;
}

int32_t native_add(int32_t x, int32_t y) {
    return x + y;
}

int32_t test_poi_service() {
    PoiService service;
    MockPoiProvider provider;
    service.setProvider(&provider);
    std::vector<Poi> pois = service.getPois(41.0, 29.0, 1000.0);
    return pois.size();
}

#ifdef __cplusplus
}
#endif
