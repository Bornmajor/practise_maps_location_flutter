import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows (and keeps updating) a notification with the live coordinates.
/// Posting again with the same id replaces the existing notification.
class TrackingNotificationService {
  TrackingNotificationService._();
  static final TrackingNotificationService instance =
      TrackingNotificationService._();

  static const int _coordinatesNotificationId = 1001;
  static const String _coordinatesChannelId = 'live_coordinates';

  // Same id geolocator uses for its foreground-service notification.
  // Creating it first (at default importance) lets us control how it shows;
  // geolocator then reuses the existing channel instead of making a silent one.
  static const String _geolocatorChannelId = 'geolocator_channel_01';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _geolocatorChannelId,
        'Location tracking',
        importance: Importance.defaultImportance,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _coordinatesChannelId,
        'Live coordinates',
        description: 'Your current latitude and longitude while tracking',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ),
    );

    _initialized = true;
  }

  Future<void> showCoordinates(double latitude, double longitude) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: _coordinatesNotificationId,
        title: 'Live location',
        body:
            'Lat ${latitude.toStringAsFixed(5)}, Lng ${longitude.toStringAsFixed(5)}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _coordinatesChannelId,
            'Live coordinates',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ongoing: true,
            onlyAlertOnce: true, // update silently, no repeated sound/popup
            playSound: false,
            enableVibration: false,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: false,
            presentBanner: true,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Failed to show coordinates notification: $error');
    }
  }

  Future<void> clear() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _coordinatesNotificationId);
    } catch (error) {
      debugPrint('Failed to clear coordinates notification: $error');
    }
  }
}
