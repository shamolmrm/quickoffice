import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

/// Notifies the owner 1 day before and on the due date of unpaid invoices.
class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _ready = true;
  }

  static int _id(BizDoc d, int k) => (d.id.hashCode & 0x0FFFFFFF) * 2 + k;

  static Future<void> schedule(BizDoc d, String currency) async {
    await init();
    for (var k = 0; k < 2; k++) {
      await _plugin.cancel(id: _id(d, k));
    }
    final due = d.dueDate;
    if (d.kind != DocKind.invoice || due == null || d.balance <= 0) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    const details = NotificationDetails(
      android: AndroidNotificationDetails('due', 'Payment due',
          channelDescription: 'Invoice due-date reminders', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    for (var k = 0; k < 2; k++) {
      final at = DateTime(due.year, due.month, due.day, 10).subtract(Duration(days: k == 0 ? 1 : 0));
      if (at.isBefore(DateTime.now())) continue;
      try {
        await _plugin.zonedSchedule(
          id: _id(d, k),
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: k == 0 ? '⏰ ${d.number} is due tomorrow' : '💰 ${d.number} is due today',
          body: '${d.client.name} owes $currency${d.balance.toStringAsFixed(2)}. Send a reminder.',
        );
      } catch (e) {
        debugPrint('reminder failed: $e');
      }
    }
  }
}
