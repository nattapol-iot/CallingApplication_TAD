import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../models/calling_job_model.dart';
import 'wakelock_service.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;

  static const int _ongoingNotiId = 999999;
  static const String _chOngoing = 'calling_channel_ongoing_v5';
  static const String _chNew = 'calling_channel_new_v5';

  Timer? _timer;
  int _count = 0;

  Future<void> init() async {
    if (_inited) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(settings: initSettings);

    // Create notification channels for Android 8+
    await _createNotificationChannels();

    _inited = true;
  }

  Future<void> _createNotificationChannels() async {
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return;

    // Channel for ongoing calling alerts
    const ongoingChannel = AndroidNotificationChannel(
      _chOngoing,
      'Calling Alert',
      description: 'แจ้งเตือนงาน CALLING ค้าง/งานใหม่',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Channel for new job notifications
    const newJobChannel = AndroidNotificationChannel(
      _chNew,
      'New Calling',
      description: 'แจ้งเตือนงานเรียกซ่อมใหม่',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await android.createNotificationChannel(ongoingChannel);
    await android.createNotificationChannel(newJobChannel);
  }

  Future<void> requestPermissionsIfNeeded() async {
    try {
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  // =========================================================
  // ✅ New job notification (เสียงระบบ + สั่น)
  // =========================================================
  Future<void> showNewJobNotification(CallingJob job) async {
    await init();

    // Wake up screen for new job
    await WakeLockService.wakeUpScreen();

    final androidDetails = AndroidNotificationDetails(
      _chNew,
      'New Calling',
      channelDescription: 'แจ้งเตือนงานเรียกซ่อมใหม่',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 300, 500]),
    );

    await _local.show(
      id: job.callingId,
      title: 'มีงานเรียกใหม่ (Line ${job.lineNo})',
      body: '${job.workOrder} - ${job.itemName}',
      notificationDetails: NotificationDetails(android: androidDetails),
    );

    _vibrateOnce();
  }

  // =========================================================
  // ✅ Loop 10s for CALLING (ongoing) - ไม่ spam (update เดิม)
  // =========================================================
  void startCallingLoop(int callingCount) {
    _count = callingCount;

    if (_timer != null) return;

    _fireOnce();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fireOnce();
    });
  }

  void updateCallingCount(int callingCount) {
    _count = callingCount;
  }

  Future<void> stopCallingLoop() async {
    _timer?.cancel();
    _timer = null;
    _count = 0;

    await init();
    await _local.cancel(id: _ongoingNotiId);

    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> _fireOnce() async {
    await init();
    if (_count <= 0) return;

    // Wake up screen when there are pending calls
    await WakeLockService.wakeUpScreen();

    final androidDetails = AndroidNotificationDetails(
      _chOngoing,
      'Calling Alert',
      channelDescription: 'แจ้งเตือนงาน CALLING ค้าง/งานใหม่',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 450, 250, 450]),
    );

    await _local.show(
      id: _ongoingNotiId,
      title: 'CALLING ค้างอยู่ ($_count งาน)',
      body: 'กรุณาตรวจสอบด่วน',
      notificationDetails: NotificationDetails(android: androidDetails),
    );

    _vibrateOnce();
  }

  Future<void> _vibrateOnce() async {
    try {
      if (await Vibration.hasCustomVibrationsSupport() == true) {
        await Vibration.vibrate(pattern: [0, 450, 250, 450], amplitude: 255);
      } else if (await Vibration.hasVibrator() == true) {
        await Vibration.vibrate(duration: 600);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Vibration error: $e');
    }
  }

  // =========================================================
  // ✅ Backward-compatible aliases (ให้ home_screen เก่าเรียกได้)
  // =========================================================

  // home_screen เก่าเรียก stopCallingOngoing()
  Future<void> stopCallingOngoing() => stopCallingLoop();

  // home_screen เก่าเรียก showCallingOngoing(count)
  Future<void> showCallingOngoing(int count) async {
    // ทำให้เหมือนเดิม: start loop แล้ว update count
    startCallingLoop(count);
    updateCallingCount(count);
  }

  // home_screen เก่าเรียก startAlertLoop(count)
  void startAlertLoop(int count) => startCallingLoop(count);

  // home_screen เก่าเรียก stopAlertLoop()
  void stopAlertLoop() => stopCallingLoop();
}
