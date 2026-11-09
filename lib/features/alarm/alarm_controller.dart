import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../services/notification_service.dart';
import 'alarm_screen.dart';

/// مفتاح التنقل العام لعرض المنبه من أي مكان.
final navigatorKey = GlobalKey<NavigatorState>();

/// يعرض المنبه بملء الشاشة:
/// - عند فتح التطبيق من إشعار المنبه (أو تنبيه ملء الشاشة على أندرويد).
/// - عند حلول وقت تذكير والتطبيق مفتوح.
class AlarmController {
  AlarmController._();
  static final instance = AlarmController._();

  Timer? _timer;
  DateTime _lastCheck = DateTime.now();
  final _showing = <int>{};
  final _queue = <AlarmPayload>[];
  bool _busy = false;

  NotificationService get _n => NotificationService.instance;

  Future<void> start() async {
    _n.onResponse = (_, p) => show(p);
    _lastCheck = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => check());
    final launch = await _n.launchAlarm();
    if (launch != null) show(launch);
  }

  void stop() => _timer?.cancel();

  /// يبحث عن التذكيرات التي حان وقتها منذ آخر فحص.
  Future<void> check() async {
    if (!_n.alarmMode) {
      _lastCheck = DateTime.now();
      return;
    }
    final now = DateTime.now();
    final from = _lastCheck;
    _lastCheck = now;
    bool inWindow(DateTime t) => t.isAfter(from) && !t.isAfter(now);

    final due = <AlarmPayload>[];
    for (final t in await taskRepo.all()) {
      if (!t.done && t.reminderAt != null && inWindow(t.reminderAt!)) {
        due.add(NotificationService.taskPayload(t));
      }
    }
    for (final e in await eventRepo.all()) {
      final at = NotificationService.eventAlarmTime(e);
      if (at != null && inWindow(at)) {
        due.add(NotificationService.eventPayload(e));
      }
    }
    due.addAll(await _n.takeDueSnoozes(now));
    for (final p in due) {
      show(p);
    }
  }

  /// يعرض شاشة المنبه (منبه واحد في كل مرة، والباقي في الانتظار).
  void show(AlarmPayload p) {
    if (_showing.contains(p.notifId) ||
        _queue.any((q) => q.notifId == p.notifId)) {
      return;
    }
    _queue.add(p);
    _next();
  }

  Future<void> _next() async {
    if (_busy || _queue.isEmpty) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _busy = true;
    final p = _queue.removeAt(0);
    _showing.add(p.notifId);
    // إيقاف رنين الإشعار لأن الشاشة ستتولى الصوت
    await _n.cancelId(p.notifId);
    final result = await nav.push<AlarmAction>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => AlarmScreen(payload: p),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 1.05, end: 1.0).animate(a),
            child: child,
          ),
        ),
      ),
    );
    _showing.remove(p.notifId);
    if (result == AlarmAction.snooze) {
      final at = await _n.snooze(p);
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        toast(ctx, 'سيعاود التنبيه الساعة ${Fmt.time(at)}');
      }
    }
    _busy = false;
    _next();
  }
}

/// زر تجربة المنبه فوراً داخل التطبيق.
void showTestAlarm() => AlarmController.instance.show(
  const AlarmPayload(
    type: 'test',
    itemId: 0,
    notifId: NotificationService.testId,
    title: '⏰ منبه تجريبي',
    body: 'هذا مثال على تنبيه المهام والمواعيد',
  ),
);

/// أيقونة جاهزة لاستخدامها في الإعدادات.
const alarmIcon = CupertinoIcons.alarm_fill;
