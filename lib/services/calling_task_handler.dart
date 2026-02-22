import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallingTaskHandler extends TaskHandler {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final FlutterLocalNotificationsPlugin _noti =
      FlutterLocalNotificationsPlugin();

  String? _wsUrl;
  int _callingCount = 0;
  bool _notiInitDone = false;
  int _reconnectAttempts = 0;
  DateTime? _lastConnectAttempt;

  static const int _notiId = 900001;
  static const int _maxReconnectAttempts = 10;
  static const Duration _minReconnectDelay = Duration(seconds: 5);

  Future<void> _initLocalNotiIfNeeded() async {
    if (_notiInitDone) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _noti.initialize(settings: initSettings);

    // Create notification channel
    final android = _noti
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      const channel = AndroidNotificationChannel(
        'calling_alert',
        'Calling Alert',
        description: 'Alert when CALLING pending',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await android.createNotificationChannel(channel);
    }

    _notiInitDone = true;
  }

  Future<void> _connectIfNeeded() async {
    _wsUrl ??= await FlutterForegroundTask.getData<String>(key: 'ws_url');

    final url = _wsUrl;
    if (url == null || url.trim().isEmpty) return;

    if (_channel != null) return;

    // Prevent too frequent reconnection attempts
    if (_lastConnectAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        _lastConnectAttempt!,
      );
      if (timeSinceLastAttempt < _minReconnectDelay) {
        return;
      }
    }

    // Stop reconnecting after max attempts (will retry on next event cycle)
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _reconnectAttempts = 0; // Reset for next cycle
    }

    _lastConnectAttempt = DateTime.now();
    _reconnectAttempts++;

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        (msg) {
          _reconnectAttempts = 0; // Reset on successful message
          _onMessage(msg);
        },
        onError: (_) => _resetSocket(),
        onDone: () => _resetSocket(),
      );
    } catch (_) {
      _resetSocket();
    }
  }

  void _resetSocket() {
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _onMessage(dynamic message) {
    try {
      final obj = jsonDecode(message.toString());
      final type = obj['type']?.toString() ?? '';

      if (type == 'CALLING_UPDATE' || type == 'CALLING_HISTORY') {
        final jobs = (obj['jobs'] as List?) ?? const [];
        final count = jobs.where((j) => (j is Map && j['status'] == 1)).length;
        _callingCount = count;
      }
    } catch (_) {}
  }

  Future<void> _fireAlertIfNeeded() async {
    if (_callingCount <= 0) {
      await _noti.cancel(id: _notiId);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'calling_alert',
      'Calling Alert',
      channelDescription: 'Alert when CALLING pending',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _noti.show(
      id: _notiId,
      title: 'CALLING ค้างอยู่ ($_callingCount งาน)',
      body: 'กรุณาตรวจสอบด่วน',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  // -------- v6.1.3 signatures --------

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    await _initLocalNotiIfNeeded();
    await _connectIfNeeded();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    await _initLocalNotiIfNeeded();
    await _connectIfNeeded();
    await _fireAlertIfNeeded();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    await _noti.cancel(id: _notiId);

    _resetSocket();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
