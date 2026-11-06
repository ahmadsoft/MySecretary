import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/format.dart';
import '../data/models.dart';

/// التذكيرات والإشعارات المحلية (تعمل بدون إنترنت).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _taskBase = 100000;
  static const _eventBase = 200000;
  static const _smsBase = 300000;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'التذكيرات',
      channelDescription: 'تذكيرات المهام والمواعيد',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _smsDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'sms_tx',
      'العمليات البنكية',
      channelDescription: 'إشعار عند تسجيل مصروف من رسالة البنك',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init({bool requestPermission = true}) async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
      if (requestPermission) await _requestPermissions();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final a = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await a?.requestNotificationsPermission();
      await a?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
    if (when.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // إذا لم يُمنح إذن المنبهات الدقيقة نستخدم التوقيت التقريبي
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> scheduleTask(Task t) async {
    if (t.id == null) return;
    if (t.done || t.reminderAt == null) {
      await cancelTask(t.id!);
      return;
    }
    final body = t.dueAt != null
        ? 'موعد الاستحقاق: ${Fmt.dateTime(t.dueAt!)}'
        : 'تذكير بمهمة';
    await _schedule(_taskBase + t.id!, '📝 ${t.title}', body, t.reminderAt!);
  }

  Future<void> cancelTask(int id) async {
    if (_ready) await _plugin.cancel(id: _taskBase + id);
  }

  Future<void> scheduleEvent(Event e) async {
    if (e.id == null) return;
    if (e.reminderMinutes == null) {
      await cancelEvent(e.id!);
      return;
    }
    final when = e.startAt.subtract(Duration(minutes: e.reminderMinutes!));
    final where = e.location.isNotEmpty ? ' - ${e.location}' : '';
    await _schedule(
      _eventBase + e.id!,
      '📅 ${e.title}',
      '${e.allDay ? Fmt.date(e.startAt) : Fmt.dateTime(e.startAt)}$where',
      when,
    );
  }

  Future<void> cancelEvent(int id) async {
    if (_ready) await _plugin.cancel(id: _eventBase + id);
  }

  Future<void> showSmsRecorded(int txId, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: _smsBase + (txId % 100000),
      title: title,
      body: body,
      notificationDetails: _smsDetails,
    );
  }
}
