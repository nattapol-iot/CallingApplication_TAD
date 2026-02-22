import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'constants/app_theme.dart';
import 'screens/login_screen.dart';
import 'services/calling_task_handler.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(CallingTaskHandler());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ init สำหรับ flutter_foreground_task (v6.x ต้องมี iosNotificationOptions)
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'calling_fg_service',
      channelName: 'Calling Foreground Service',
      channelDescription: 'Keep websocket running in background',
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
      interval: 5000, // ✅ 5 วิ
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASAHI DENSO Calling',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const LoginPage(),
    );
  }
}
