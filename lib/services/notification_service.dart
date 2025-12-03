import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Pastikan icon 'ic_launcher' ada di folder android/app/src/main/res/mipmap...
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  Future<void> scheduleNotificationNow({
    required String title,
    required String body,
    int delaySeconds = 3,
    int notificationId = 2
  }) async {
    final DateTime triggerTime = DateTime.now().add(Duration(seconds: delaySeconds));

    try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
         tz.initializeTimeZones();
         try {
             tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
         } catch (e2) {
             tz.setLocalLocation(tz.UTC);
         }
    }
    
    // Pastikan scheduledDate tidak di masa lalu
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(triggerTime, tz.local);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = now.add(const Duration(seconds: 1));
    }

    await flutterLocalNotificationsPlugin.cancel(notificationId);

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'diary_channel_v1',
      'Diary Notifications',
      channelDescription: 'Notifikasi untuk aplikasi Diary',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}