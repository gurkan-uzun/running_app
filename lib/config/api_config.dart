/// API Configuration
/// Change the baseUrl here when deploying to production
class ApiConfig {
  // Development - local server
  // static const String baseUrl = 'http://localhost:8080';
  
  // Production - change to your server URL
  static const String baseUrl = 'http://34.123.19.47:8080';
  
  // Endpoints
  static const String health = '/api/health';
  static const String initGraph = '/api/init-graph';
  static const String getRoute = '/api/get-route';
  static const String optimizeRoute = '/api/optimize-route';
  static const String nearestNode = '/api/nearest-node';
  static const String nearestNodesBatch = '/api/nearest-nodes'; // Batch endpoint
  static const String pois = '/api/pois'; // Fetch POIs from backend
  
  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration optimizeTimeout = Duration(seconds: 60);
}
