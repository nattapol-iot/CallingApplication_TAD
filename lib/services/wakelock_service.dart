import 'package:flutter/services.dart';

/// Service to manage screen wake lock and turn on screen when notifications arrive
class WakeLockService {
  static const MethodChannel _channel = MethodChannel('calling_app/wakelock');

  /// Turn on screen and keep it awake
  static Future<void> wakeUpScreen() async {
    try {
      await _channel.invokeMethod('wakeUpScreen');
    } catch (e) {
      // Silently fail if platform doesn't support
    }
  }

  /// Release wake lock
  static Future<void> releaseWakeLock() async {
    try {
      await _channel.invokeMethod('releaseWakeLock');
    } catch (e) {
      // Silently fail if platform doesn't support
    }
  }

  /// Request to disable battery optimization
  static Future<void> requestDisableBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      // Silently fail if platform doesn't support
    }
  }
}
