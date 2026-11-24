import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:practise_maps_location_flutter/presentations/states/location_state.dart';

class LocationFetchScreen extends StatefulWidget {
  const LocationFetchScreen({super.key});

  @override
  State<LocationFetchScreen> createState() => _LocationFetchScreenState();
}

class _LocationFetchScreenState extends State<LocationFetchScreen> {
  LocationState state = const LocationState();
  StreamSubscription<Position>? _positionSubscription;

  /// Shared dialog: Cancel, or open the given settings page.
  Future<void> _showSettingsDialog({
    required String title,
    required String message,
    required Future<bool> Function() onOpenSettings,
  }) {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // close dialog first
              await onOpenSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> startListening() async {
    // Start loading; omitting errorMessage clears any old error.
    setState(() {
      state = state.copyWith(isLoading: true);
    });

    try {
      // 1. Is the device's location service (GPS) on?
      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        if (!mounted) return;
        setState(() {
          state = state.copyWith(
            isLoading: false,
            errorMessage: "Location service turned off",
          );
        });
        await _showSettingsDialog(
          title: 'Location service is off',
          message: 'Turn on location (GPS) in your device settings to continue.',
          onOpenSettings: Geolocator.openLocationSettings,
        );
        return;
      }

      // 2. Do we have permission? Ask if not.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          state = state.copyWith(
            isLoading: false,
            errorMessage: "Location permission was denied.",
          );
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          state = state.copyWith(
            isLoading: false,
            errorMessage: "Location permission is permanently denied.",
          );
        });
        await _showSettingsDialog(
          title: 'Location permission required',
          message:
              'Location permission is permanently denied. Open app settings and enable it to continue.',
          onOpenSettings: Geolocator.openAppSettings,
        );
        return;
      }

      // 3. Permission granted: listen to position updates.
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // only emit after moving 10 metres
      );

      if (!mounted) return;
      await _positionSubscription?.cancel(); // never run two listeners
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          if (!mounted) return;
          setState(() {
            // first update ends the loading spinner
            state = state.copyWith(
              isLoading: false,
              isListening: true,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          });
        },
        onError: (error) {
          debugPrint("Location stream error: $error");
          if (!mounted) return;
          setState(() {
            state = state.copyWith(
              isLoading: false,
              isListening: false,
              errorMessage: "Something went wrong",
            );
          });
        },
      );
    } catch (error) {
      debugPrint("Failed to start listening: $error");
      if (!mounted) return;
      setState(() {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Something went wrong",
        );
      });
    }
  }

  Future<void> stopListening() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (!mounted) return;
    setState(() {
      state = state.copyWith(isLoading: false, isListening: false);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${state.latitude ?? 0}, ${state.longitude ?? 0}",
            ),
            const SizedBox(height: 20.0),
            if (state.errorMessage != null) ...[
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20.0),
            ],
            if (state.isLoading)
              const CircularProgressIndicator()
            else if (state.isListening)
              ElevatedButton(
                onPressed: stopListening,
                child: const Text('Stop tracking'),
              )
            else
              ElevatedButton(
                onPressed: startListening,
                child: const Text('Start tracking'),
              ),
          ],
        ),
      ),
    );
  }
}
