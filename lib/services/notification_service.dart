import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps the native Windows toast notifications so the timer can alert the
/// user when a phase (focus or break) finishes.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windows = WindowsInitializationSettings(
      appName: 'Chromodoro',
      appUserModelId: 'com.chromodoro.app',
      guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
    );
    const settings = InitializationSettings(android: android, windows: windows);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'chromodoro',
        'Chromodoro',
        channelDescription: 'Pomodoro session alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
      windows: WindowsNotificationDetails(),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
