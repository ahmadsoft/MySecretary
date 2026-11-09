import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/format.dart';
import '../data/db.dart';
import '../data/models.dart';
import 'alarmkit_service.dart';

/// بيانات المنبه المحمولة داخل الإشعار (تكفي لعرضه وتأجيله بدون قاعدة البيانات).
class AlarmPayload {
  final String type; // task | event | test
  final int itemId;
  final int notifId;
  final String title;
  final String body;

  const AlarmPayload({
    required this.type,
    required this.itemId,
    required this.notifId,
    required this.title,
    required this.body,
  });

  String encode() => jsonEncode({
    't': type,
    'i': itemId,
    'n': notifId,
    'ti': title,
    'b': body,
  });

  static AlarmPayload? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return AlarmPayload(
        type: m['t'] as String,
        itemId: m['i'] as int,
        notifId: m['n'] as int,
        title: m['ti'] as String,
        body: m['b'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// يُستدعى عند الضغط على إشعار أو أحد أزراره والتطبيق مفتوح.
typedef AlarmResponseHandler = void Function(String? actionId, AlarmPayload p);

/// التذكيرات والإشعارات المحلية (تعمل بدون إنترنت)،
/// مع "وضع المنبه": تنبيه بملء الشاشة وصوت مستمر وزرّا إيقاف وتأجيل 10 دقائق.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _taskBase = 100000;
  static const _eventBase = 200000;
  static const _smsBase = 300000;
  static const testId = 399999;

  static const kAlarmMode = 'alarm_mode';
  static const kSnoozes = 'alarm_snoozes';
  static const snoozeMinutes = 10;
  static const actionSnooze = 'snooze';
  static const actionDismiss = 'dismiss';

  /// وضع المنبه بملء الشاشة (مفعل افتراضياً).
  bool alarmMode = true;
  AlarmResponseHandler? onResponse;

  static int taskNotifId(int id) => _taskBase + id;
  static int eventNotifId(int id) => _eventBase + id;

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

  static final _alarmDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'alarms_v1',
      'المنبه',
      channelDescription: 'تنبيه المهام والمواعيد بملء الشاشة مثل منبه الجهاز',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      // FLAG_INSISTENT: يتكرر الصوت حتى يتم الإيقاف أو التأجيل
      additionalFlags: Int32List.fromList(<int>[4]),
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      timeoutAfter: 10 * 60 * 1000,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 800, 600, 800, 600, 800]),
      actions: const [
        AndroidNotificationAction(
          actionSnooze,
          'تأجيل 10 دقائق',
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionDismiss,
          'إيقاف',
          cancelNotification: true,
        ),
      ],
    ),
    iOS: const DarwinNotificationDetails(
      categoryIdentifier: 'alarm',
      interruptionLevel: InterruptionLevel.timeSensitive,
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
    ),
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
      alarmMode =
          (await SharedPreferences.getInstance()).getBool(kAlarmMode) ?? true;
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: [
              DarwinNotificationCategory(
                'alarm',
                actions: [
                  DarwinNotificationAction.plain(
                    actionSnooze,
                    'تأجيل 10 دقائق',
                  ),
                  DarwinNotificationAction.plain(
                    actionDismiss,
                    'إيقاف',
                    options: const {DarwinNotificationActionOption.destructive},
                  ),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: alarmBackgroundHandler,
      );
      _ready = true;
      await AlarmKitService.instance.init();
      if (requestPermission) await _requestPermissions();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  void _onResponse(NotificationResponse r) {
    final p = AlarmPayload.decode(r.payload);
    if (p == null) return;
    if (r.actionId == actionSnooze) {
      snooze(p);
    } else if (r.actionId == actionDismiss) {
      cancelId(p.notifId);
    } else {
      onResponse?.call(r.actionId, p);
    }
  }

  /// إذا فُتح التطبيق بسبب منبه (ضغط على الإشعار أو تنبيه ملء الشاشة).
  Future<AlarmPayload?> launchAlarm() async {
    if (!_ready) return null;
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      final r = d?.notificationResponse;
      if (d?.didNotificationLaunchApp != true ||
          r == null ||
          r.actionId != null) {
        return null;
      }
      return AlarmPayload.decode(r.payload);
    } catch (_) {
      return null;
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
      await requestFullScreenPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// أندرويد 14+: إذن عرض التنبيه بملء الشاشة (يُطلب مرة واحدة).
  Future<void> requestFullScreenPermission({bool force = false}) async {
    if (!Platform.isAndroid || !alarmMode) return;
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool('fsi_asked') ?? false)) return;
    await prefs.setBool('fsi_asked', true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestFullScreenIntentPermission();
  }

  Future<void> setAlarmMode(bool v) async {
    alarmMode = v;
    await (await SharedPreferences.getInstance()).setBool(kAlarmMode, v);
    if (v) await requestFullScreenPermission(force: true);
    await rescheduleAll();
  }

  Future<void> _schedule(AlarmPayload p, DateTime when, {bool? alarm}) async {
    if (!_ready) return;
    await _plugin.cancel(id: p.notifId);
    final kit = AlarmKitService.instance;
    await kit.cancel(p.notifId);
    if (when.isBefore(DateTime.now())) return;
    final useAlarm = alarm ?? alarmMode;
    // iOS 26: منبه النظام بملء الشاشة بدل الإشعار
    if (useAlarm &&
        await kit.schedule(
          notifId: p.notifId,
          title: p.title.replaceFirst(
            RegExp(r'^[📝📅⏰]\s*', unicode: true),
            '',
          ),
          at: when,
          isEvent: p.type == 'event',
        )) {
      return;
    }
    final details = useAlarm ? _alarmDetails : _details;
    final date = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: p.notifId,
        title: p.title,
        body: p.body,
        payload: p.encode(),
        scheduledDate: date,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    } catch (_) {
      // إذا لم يُمنح إذن المنبهات الدقيقة نستخدم التوقيت التقريبي
      await _plugin.zonedSchedule(
        id: p.notifId,
        title: p.title,
        body: p.body,
        payload: p.encode(),
        scheduledDate: date,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static AlarmPayload taskPayload(Task t) => AlarmPayload(
    type: 'task',
    itemId: t.id!,
    notifId: taskNotifId(t.id!),
    title: '📝 ${t.title}',
    body: t.dueAt != null
        ? 'موعد الاستحقاق: ${Fmt.dateTime(t.dueAt!)}'
        : 'تذكير بمهمة',
  );

  static AlarmPayload eventPayload(Event e) => AlarmPayload(
    type: 'event',
    itemId: e.id!,
    notifId: eventNotifId(e.id!),
    title: '📅 ${e.title}',
    body:
        '${e.allDay ? Fmt.date(e.startAt) : Fmt.dateTime(e.startAt)}'
        '${e.location.isNotEmpty ? ' - ${e.location}' : ''}',
  );

  static DateTime? eventAlarmTime(Event e) => e.reminderMinutes == null
      ? null
      : e.startAt.subtract(Duration(minutes: e.reminderMinutes!));

  Future<void> scheduleTask(Task t) async {
    if (t.id == null) return;
    if (t.done || t.reminderAt == null) {
      await cancelTask(t.id!);
      return;
    }
    await _schedule(taskPayload(t), t.reminderAt!);
  }

  Future<void> cancelTask(int id) => cancelId(taskNotifId(id));

  Future<void> scheduleEvent(Event e) async {
    if (e.id == null) return;
    final when = eventAlarmTime(e);
    if (when == null) {
      await cancelEvent(e.id!);
      return;
    }
    await _schedule(eventPayload(e), when);
  }

  Future<void> cancelEvent(int id) => cancelId(eventNotifId(id));

  Future<void> cancelId(int notifId) async {
    if (_ready) await _plugin.cancel(id: notifId);
    await AlarmKitService.instance.cancel(notifId);
    await _removeSnooze(notifId);
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
    await AlarmKitService.instance.cancelAll();
    await (await SharedPreferences.getInstance()).remove(kSnoozes);
  }

  /// تأجيل المنبه 10 دقائق.
  Future<DateTime> snooze(AlarmPayload p) async {
    final at = DateTime.now().add(const Duration(minutes: snoozeMinutes));
    await _schedule(p, at, alarm: true);
    // نحفظ التأجيل ليعرضه التطبيق بملء الشاشة إن كان مفتوحاً وقتها
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list =
        (prefs.getStringList(kSnoozes) ?? [])
            .where((s) => (jsonDecode(s) as Map)['n'] != p.notifId)
            .toList()
          ..add(
            jsonEncode({
              'n': p.notifId,
              'at': at.millisecondsSinceEpoch,
              'p': p.encode(),
            }),
          );
    await prefs.setStringList(kSnoozes, list);
    return at;
  }

  /// التأجيلات التي حان وقتها (وتُحذف من القائمة).
  Future<List<AlarmPayload>> takeDueSnoozes(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = prefs.getStringList(kSnoozes) ?? [];
    final due = <AlarmPayload>[];
    final keep = <String>[];
    for (final s in list) {
      final m = jsonDecode(s) as Map;
      if ((m['at'] as int) <= now.millisecondsSinceEpoch) {
        final p = AlarmPayload.decode(m['p'] as String);
        if (p != null) due.add(p);
      } else {
        keep.add(s);
      }
    }
    if (due.isNotEmpty) await prefs.setStringList(kSnoozes, keep);
    return due;
  }

  Future<void> _removeSnooze(int notifId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kSnoozes);
    if (list == null) return;
    final keep = list
        .where((s) => (jsonDecode(s) as Map)['n'] != notifId)
        .toList();
    if (keep.length != list.length) await prefs.setStringList(kSnoozes, keep);
  }

  /// منبه تجريبي بعد ثوانٍ (لتجربة الشاشة المقفلة).
  Future<void> scheduleTest(Duration after) => _schedule(
    AlarmPayload(
      type: 'test',
      itemId: 0,
      notifId: testId,
      title: '⏰ منبه تجريبي',
      body: 'هذا مثال على تنبيه المهام والمواعيد',
    ),
    DateTime.now().add(after),
    alarm: true,
  );

  /// إعادة جدولة كل التذكيرات (بعد تغيير الوضع أو استعادة نسخة احتياطية).
  Future<void> rescheduleAll() async {
    final db = await AppDb.instance;
    if (_ready) await _plugin.cancelAll();
    await AlarmKitService.instance.cancelAll();
    for (final r in await db.query(
      'tasks',
      where: 'done = 0 AND reminder_at IS NOT NULL',
    )) {
      await scheduleTask(Task.fromMap(r));
    }
    for (final r in await db.query(
      'events',
      where: 'reminder_minutes IS NOT NULL',
    )) {
      await scheduleEvent(Event.fromMap(r));
    }
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

/// يعمل عند الضغط على "تأجيل" أو "إيقاف" من الإشعار والتطبيق مغلق.
@pragma('vm:entry-point')
Future<void> alarmBackgroundHandler(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final p = AlarmPayload.decode(r.payload);
  if (p == null) return;
  final n = NotificationService.instance;
  await n.init(requestPermission: false);
  if (r.actionId == NotificationService.actionSnooze) {
    await n.snooze(p);
  } else if (r.actionId == NotificationService.actionDismiss) {
    await n.cancelId(p.notifId);
  }
}
