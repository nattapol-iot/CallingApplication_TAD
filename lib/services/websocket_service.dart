import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _watchdogTimer;

  bool _isConnecting = false;
  bool _isConnected = false;

  DateTime _lastMessageAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _retryCount = 0;

  Function(dynamic)? onMessage;
  Function(String)? onError;
  Function(bool)? onStatusChange;

  void connect(String url) {
    if (_isConnecting) return;

    _isConnecting = true;
    _stopTimers();

    // ปิดของเก่า
    _channel?.sink.close();
    _channel = null;

    _setConnected(false);

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);

      // เริ่ม listen ก่อน แล้วค่อยบอกว่า connected
      _channel!.stream.listen(
        (message) {
          _lastMessageAt = DateTime.now();
          _retryCount = 0; // ได้ message แสดงว่าลิงก์ยังมีชีวิต
          onMessage?.call(message);
        },
        onError: (e) => _handleError('WS error: $e', url),
        onDone: () => _handleError('WS closed', url),
        cancelOnError: true,
      );

      _lastMessageAt = DateTime.now();
      _setConnected(true);

      _startHeartbeat(url);
      sendJson({'type': 'PING'});
    } catch (e) {
      _handleError('WS connect exception: $e', url);
    } finally {
      _isConnecting = false;
    }
  }

  void _setConnected(bool value) {
    if (_isConnected == value) return;
    _isConnected = value;
    onStatusChange?.call(value);
  }

  void _startHeartbeat(String url) {
    // ส่ง ping ทุก 20 วิ
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      sendJson({'type': 'PING'});
    });

    // ถ้าไม่เห็น message นานเกิน 45 วิ ให้ reconnect (กันหลุดเงียบ)
    _watchdogTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final diff = DateTime.now().difference(_lastMessageAt);
      if (diff > const Duration(seconds: 45)) {
        _handleError('WS watchdog timeout (${diff.inSeconds}s)', url);
      }
    });
  }

  void _handleError(String errorMsg, String url) {
    if (kDebugMode) debugPrint(errorMsg);

    // Only call error callback if it's still set (not disposed)
    if (onError != null) {
      onError?.call(errorMsg);
    }

    _setConnected(false);

    _stopTimers();

    try {
      _channel?.sink.close();
    } catch (e) {
      if (kDebugMode) debugPrint('Error closing channel: $e');
    }

    _channel = null;

    _scheduleReconnect(url);
  }

  void _scheduleReconnect(String url) {
    _reconnectTimer?.cancel();

    // backoff: 5, 8, 13, 21, 30, 30...
    final delays = [5, 8, 13, 21, 30];
    final sec = delays[_retryCount.clamp(0, delays.length - 1)];
    _retryCount++;

    _reconnectTimer = Timer(Duration(seconds: sec), () => connect(url));

    if (kDebugMode) {
      debugPrint('WS reconnect scheduled in ${sec}s (retry=$_retryCount)');
    }
  }

  void sendJson(Map<String, dynamic> data) {
    final ch = _channel;
    if (ch == null) return;

    final text = jsonEncode(data);

    if (kDebugMode && data['type'] != 'PING') {
      debugPrint('WS SEND: $text');
    }

    try {
      ch.sink.add(text);
    } catch (e) {
      // ถ้าส่งไม่ได้ ให้เข้าสู่ flow reconnect
      if (kDebugMode) debugPrint('WS send failed: $e');
    }
  }

  void disconnect() {
    _stopTimers();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setConnected(false);
  }

  void _stopTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;

    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // ✅ ตัด callback ทิ้ง เพื่อกันยิงกลับไปหน้าเดิม
    onMessage = null;
    onError = null;
    onStatusChange = null;

    _channel?.sink.close();
    _channel = null;
  }
}
