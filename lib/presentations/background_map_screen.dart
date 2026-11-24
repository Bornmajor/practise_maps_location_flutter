import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:practise_maps_location_flutter/presentations/states/location_state.dart';
import 'package:practise_maps_location_flutter/services/tracking_notification_service.dart';

/// Live map that keeps tracking while the app is in the background.
/// Android: foreground service + persistent notification.
/// iOS: "location" background mode + blue status-bar indicator.
class BackgroundMapScreen extends StatefulWidget {
  const BackgroundMapScreen({super.key});

  @override
  State<BackgroundMapScreen> createState() => _BackgroundMapScreenState();
}

class _BackgroundMapScreenState extends State<BackgroundMapScreen> {
  static const LatLng _defaultCenter = LatLng(-3.51064, 39.86535);
  static const double _defaultZoom = 16;

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;

  LocationState state = const LocationState();
  final List<LatLng> _trail = []; // every point received, drawn as a line
  bool _mapReady = false;
  bool _followUser = true;
  Future<bool> Function()? _settingsAction;

  LatLng? get _currentPoint {
    final lat = state.latitude;
    final lng = state.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    startTracking();
  }

  @override
  void dispose() {
    // Leaving this screen stops tracking (and removes the notification).
    _positionSubscription?.cancel();
    TrackingNotificationService.instance.clear();
    _mapController.dispose();
    super.dispose();
  }

  /// Platform-specific settings. The Android foreground notification config
  /// is what turns the stream into a foreground service.
  LocationSettings _buildLocationSettings() {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Live location tracking',
          notificationText: 'Your location is being tracked in the background',
          notificationChannelName: 'Location tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (_isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
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

  Future<void> startTracking() async {
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

      // 1. Normal location permission ("while in use").
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

      // Prepare notification channels (must happen before the stream starts).
      await TrackingNotificationService.instance.init();

      // 2. Android extras. Neither blocks tracking if refused: a foreground
      //    service started while the app is visible keeps location access.
      if (_isAndroid) {
        // Android 13+: needed so the tracking notification is visible.
        if (!await Permission.notification.isGranted) {
          await Permission.notification.request();
        }
        // Android 10+: "Allow all the time". On 11+ this opens system settings.
        if (!await Permission.locationAlways.isGranted) {
          await Permission.locationAlways.request();
        }
      }
      // iOS: geolocator upgrades to "Always" because
      // NSLocationAlwaysAndWhenInUseUsageDescription is in Info.plist.

      if (!mounted) return;
      await _positionSubscription?.cancel(); // never run two listeners
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _buildLocationSettings(),
      ).listen(
        _onPosition,
        onError: (error) {
          debugPrint("Location stream error: $error");
          _setError("Something went wrong");
        },
      );
    } catch (error) {
      debugPrint("Failed to start tracking: $error");
      _setError("Something went wrong");
    }
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel(); // also stops the notification
    _positionSubscription = null;
    await TrackingNotificationService.instance.clear();
    if (!mounted) return;
    setState(() {
      state = state.copyWith(isLoading: false, isListening: false);
    });
  }

  void _onPosition(Position position) {
    // Update the notification even if the screen is gone from view.
    TrackingNotificationService.instance.showCoordinates(
      position.latitude,
      position.longitude,
    );
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _trail.add(point);
      state = state.copyWith(
        isLoading: false,
        isListening: true,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });

    if (_followUser && _mapReady) {
      _mapController.move(point, _mapController.camera.zoom);
    }
  }

  void _recenter() {
    final point = _currentPoint;
    if (point == null) return;
    setState(() => _followUser = true);
    if (_mapReady) _mapController.move(point, _defaultZoom);
  }

  @override
  Widget build(BuildContext context) {
    final point = _currentPoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Background tracking"),
        actions: [
          if (state.isListening)
            TextButton.icon(
              onPressed: stopTracking,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop'),
            )
          else if (!state.isLoading)
            TextButton.icon(
              onPressed: startTracking,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start'),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: point ?? _defaultCenter,
              initialZoom: _defaultZoom,
              onMapReady: () {
                _mapReady = true;
                final current = _currentPoint;
                if (current != null) {
                  _mapController.move(current, _defaultZoom);
                }
              },
              onPositionChanged: (camera, hasGesture) {
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
              if (_trail.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trail,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
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
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
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
                          onPressed: startTracking,
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
