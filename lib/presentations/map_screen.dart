import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:practise_maps_location_flutter/presentations/states/location_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultCenter = LatLng(-3.51064, 39.86535);
  static const double _defaultZoom = 16;

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;

  LocationState state = const LocationState();
  bool _mapReady = false;
  bool _followUser = true; // camera follows the user until they pan the map

  // Which settings page the error banner should open (null = no button).
  Future<bool> Function()? _settingsAction;

  LatLng? get _currentPoint {
    final lat = state.latitude;
    final lng = state.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    startListening();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _setError(String message, {Future<bool> Function()? settingsAction}) {
    if (!mounted) return;
    setState(() {
      _settingsAction = settingsAction;
      state = state.copyWith(
        isLoading: false,
        isListening: false,
        errorMessage: message,
      );
    });
  }

  Future<void> startListening() async {
    setState(() {
      _settingsAction = null;
      state = state.copyWith(isLoading: true); // clears old error
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setError(
          "Location service is turned off.",
          settingsAction: Geolocator.openLocationSettings,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setError("Location permission was denied.");
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setError(
          "Location permission is permanently denied.",
          settingsAction: Geolocator.openAppSettings,
        );
        return;
      }

      if (!mounted) return;
      await _positionSubscription?.cancel(); // never run two listeners
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        _onPosition,
        onError: (error) {
          debugPrint("Location stream error: $error");
          _setError("Something went wrong");
        },
      );
    } catch (error) {
      debugPrint("Failed to start listening: $error");
      _setError("Something went wrong");
    }
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    setState(() {
      state = state.copyWith(
        isLoading: false,
        isListening: true,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });

    if (_followUser && _mapReady) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  void _recenter() {
    final point = _currentPoint;
    if (point == null) {
      startListening(); // no fix yet: (re)try
      return;
    }
    setState(() => _followUser = true);
    if (_mapReady) _mapController.move(point, _defaultZoom);
  }

  @override
  Widget build(BuildContext context) {
    final point = _currentPoint;

    return Scaffold(
      appBar: AppBar(title: const Text("Open street maps")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: point ?? _defaultCenter,
              initialZoom: _defaultZoom,
              onMapReady: () {
                _mapReady = true;
                // A fix may have arrived before the map was ready.
                final current = _currentPoint;
                if (current != null) {
                  _mapController.move(current, _defaultZoom);
                }
              },
              onPositionChanged: (camera, hasGesture) {
                // User dragged/zoomed the map: stop auto-following.
                if (hasGesture && _followUser) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.practise_maps_location_flutter',
              ),
              if (point != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          if (state.isLoading) const LinearProgressIndicator(),
          if (state.errorMessage != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(state.errorMessage!)),
                      if (_settingsAction != null)
                        TextButton(
                          onPressed: () => _settingsAction!(),
                          child: const Text('Open settings'),
                        )
                      else
                        TextButton(
                          onPressed: startListening,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenter,
        child: Icon(_followUser ? Icons.my_location : Icons.location_searching),
      ),
    );
  }
}
