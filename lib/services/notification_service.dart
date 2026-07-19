import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize timezone database
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
      print("❌ NotificationService: Gagal menyetel local timezone: $e");
    }

    // 2. Initialize Flutter Local Notifications settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        print("🔔 Notifikasi diklik: ${details.payload}");
      },
    );

    // 3. Request permissions for Android 13+ and iOS
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      try {
        await androidImplementation?.requestNotificationsPermission();
      } catch (e) {
        print("⚠️ Gagal meminta izin notifikasi Android 13+: $e");
      }

      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (e) {
        print("⚠️ Gagal meminta izin exact alarm Android: $e");
      }
    } else if (Platform.isIOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      try {
        await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        print("⚠️ Gagal meminta izin notifikasi iOS: $e");
      }
    }
  }

  /// Helper to convert a string (like a Firestore Document ID) into a unique positive 32-bit integer.
  int getUniqueId(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = 31 * hash + input.codeUnitAt(i);
    }
    return hash & 0x7FFFFFFF; // Make sure it fits in a 32-bit positive integer
  }

  /// Show an instant/immediate notification on the device
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transaksi',
      channelDescription: 'Notifikasi untuk aktivitas transaksi keuangan',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Schedule a notification for a specific future date and time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // If the scheduled date has already passed, trigger it in 5 seconds or ignore
    DateTime triggerTime = scheduledDate;
    if (triggerTime.isBefore(DateTime.now())) {
      triggerTime = DateTime.now().add(const Duration(seconds: 5));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'due_date_channel',
      'Jatuh Tempo',
      channelDescription: 'Notifikasi pengingat jatuh tempo beban wajib',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(triggerTime, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      print("📅 Berhasil menjadwalkan notifikasi ID: $id pada $triggerTime");
    } catch (e) {
      print("❌ Gagal menjadwalkan notifikasi ID: $id. Error: $e");
      // Fallback: schedule using inexact scheduling mode if exact alarm fails
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(triggerTime, tz.local),
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        print("📅 [Fallback] Berhasil menjadwalkan notifikasi inexact ID: $id pada $triggerTime");
      } catch (ex) {
        print("❌ [Fallback] Gagal menjadwalkan notifikasi inexact: $ex");
      }
    }
  }

  /// Cancel a scheduled notification by its ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    print("🗑️ Membatalkan notifikasi terjadwal ID: $id");
  }
}
