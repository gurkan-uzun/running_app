import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

// FFI Typedefs
typedef InitGraphFunc = Int32 Function(Pointer<Utf8> path);
typedef InitGraph = int Function(Pointer<Utf8> path);

typedef GetRouteFunc = Int32 Function(Double startLat, Double startLon, Double endLat, Double endLon, Pointer<Double> outCoords, Int32 maxCapacity);
typedef GetRoute = int Function(double startLat, double startLon, double endLat, double endLon, Pointer<Double> outCoords, int maxCapacity);

typedef GetLastErrorFunc = Void Function(Pointer<Utf8> buffer, Int32 length);
typedef GetLastError = void Function(Pointer<Utf8> buffer, int length);

class NativeService {
  late DynamicLibrary _nativeLib;
  late InitGraph _initGraph;
  late GetRoute _getRoute;
  late GetLastError _getLastError;

  NativeService() {
    _nativeLib = _loadLibrary();
    
    _initGraph = _nativeLib
        .lookup<NativeFunction<InitGraphFunc>>('init_graph')
        .asFunction();
        
    _getRoute = _nativeLib
        .lookup<NativeFunction<GetRouteFunc>>('get_route')
        .asFunction();

    _getLastError = _nativeLib
        .lookup<NativeFunction<GetLastErrorFunc>>('get_last_error')
        .asFunction();

    _initializeLogging();
    _registerLogger();
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libnative_running_app.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libnative_running_app.dylib'); // MacOS dev
    }
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }
  
  Future<void> _initializeLogging() async {
    try {
        final dir = await getApplicationDocumentsDirectory();
        final logPath = "${dir.path}/native_debug.log";
        print("Dart: Initializing Native Logging to $logPath");
        
        final initLog = _nativeLib
            .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('init_logging')
            .asFunction<void Function(Pointer<Utf8>)>();
            
        final pathPtr = logPath.toNativeUtf8();
        initLog(pathPtr);
        calloc.free(pathPtr);
    } catch (e) {
        print("Failed to init file logging: $e");
    }
  }

  void _registerLogger() {
    // This method is currently empty as per the provided instruction snippet.
    // If there's native logger registration logic, it would go here.
  }

  // Returns number of nodes loaded, or -1 on error
  // Accepts XML String content now, not path
  Future<int> initGraph(String xmlContent) async {
    final nativeInit = _nativeLib
        .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('init_graph')
        .asFunction<int Function(Pointer<Utf8>)>();

    final contentPtr = xmlContent.toNativeUtf8();
    final result = nativeInit(contentPtr);
    calloc.free(contentPtr);
    
    return result;
  }
  
  String getLastError() {
    try {
        final nativeGetLastError = _nativeLib
            .lookup<NativeFunction<Void Function(Pointer<Utf8>, Int32)>>('get_last_error')
            .asFunction<void Function(Pointer<Utf8>, int)>();
            
        final buffer = calloc<Uint8>(256);
        nativeGetLastError(buffer.cast(), 256);
        String error = buffer.cast<Utf8>().toDartString();
        calloc.free(buffer);
        return error;
    } catch (e) {
        return "Could not retrieve native error: $e";
    }
  }

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    const int maxPoints = 5000;
    // Allocate buffer for [lat, lon, lat, lon...]
    final Pointer<Double> coordsPtr = calloc<Double>(maxPoints * 2);

    try {
      final count = _getRoute(start.latitude, start.longitude, end.latitude, end.longitude, coordsPtr, maxPoints * 2);
      
      if (count <= 0) return [];

      final List<LatLng> route = [];
      for (int i = 0; i < count; i++) {
        route.add(LatLng(coordsPtr[i * 2], coordsPtr[i * 2 + 1]));
      }
      return route;
    } finally {
      calloc.free(coordsPtr);
    }
  }
}
