import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'calling_task_handler.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(CallingTaskHandler());
}

class ForegroundCallingService {
  static bool _started = false;

  static Future<void> start({required String wsUrl}) async {
    await FlutterForegroundTask.saveData(key: 'ws_url', value: wsUrl);

    if (_started) return;

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'ASAHI DENSO Calling',
        notificationText: 'Running in background (5s)',
        callback: startCallback,
      );
    }
    _started = true;
  }

  static Future<void> stop() async {
    _started = false;
    await FlutterForegroundTask.stopService();
  }
}
