import 'dart:isolate';
import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'odoo_service.dart';

@pragma('vm:entry-point')
void locationCallback(LocationDto location) async {
  await OdooService.loadFromPrefs();
  await OdooService.sendPing(
    lat: location.latitude,
    lng: location.longitude,
    accuracy: location.accuracy,
    speed: location.speed,
    heading: location.heading,
    altitude: location.altitude,
  );
}

@pragma('vm:entry-point')
void initCallback(Map<dynamic, dynamic> params) {}

@pragma('vm:entry-point')
void disposeCallback() {}

@pragma('vm:entry-point')
void notificationCallback() {}

class LocationService {
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  static Future<void> initialize() async {
    await BackgroundLocator.initialize();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'odoo_location_tracker',
        channelName: 'Location Tracking',
        channelDescription: 'Sharing your location with Odoo',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 30000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Ask for location permissions then start tracking automatically.
  /// Called right after login — no button press needed.
  static Future<void> requestPermissionsAndStart() async {
    // 1. Ask for "while in use" first (required before "always")
    final whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) return; // user denied — can't track

    // 2. Ask for background / "always" permission
    final always = await Permission.locationAlways.request();
    // Even if "always" is denied, we still start — foreground only
    // The OS will keep it alive as long as the foreground notification shows

    await startTracking();
  }

  static Future<void> startTracking() async {
    if (_isRunning) return;

    final isRegistered = await BackgroundLocator.isServiceRunning();
    if (isRegistered) await BackgroundLocator.unRegisterLocationUpdate();

    await BackgroundLocator.registerLocationUpdate(
      locationCallback,
      initCallback: initCallback,
      disposeCallback: disposeCallback,
      autoStop: false,
      iosSettings: const IOSSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        distanceFilter: 0,
        stopWithTerminate: false,
      ),
      androidSettings: AndroidSettings(
        accuracy: LocationAccuracy.HIGH,
        interval: 30,
        distanceFilter: 5,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: 'Odoo Location Tracking',
          notificationTitle: 'Location Sharing Active',
          notificationMsg: 'Your location is being shared with your company',
          notificationBigMsg:
              'Tap to open the app.',
          notificationIcon: '',
          notificationIconColor: Colors.transparent,
          notificationTapCallback: notificationCallback,
        ),
      ),
    );

    _isRunning = true;
  }

  static Future<void> stopTracking() async {
    await BackgroundLocator.unRegisterLocationUpdate();
    await OdooService.markOffline();
    _isRunning = false;
  }

  static Future<bool> isTracking() async {
    return await BackgroundLocator.isServiceRunning();
  }
}

class Colors {
  static const transparent = 0x00000000;
}
