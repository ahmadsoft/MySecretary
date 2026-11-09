import 'package:alarm_kit/alarm_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// منبه النظام في iOS 26 (AlarmKit): يرن بملء الشاشة فوق شاشة القفل
/// حتى في الوضع الصامت، مع زرّي "إيقاف" و"تأجيل 10 دقائق" من النظام نفسه.
class AlarmKitService {
  AlarmKitService._();
  static final instance = AlarmKitService._();

  static const kEnabled = 'use_alarmkit';
  static const snooze = Duration(minutes: 10);

  final _kit = AlarmKit.instance;
  bool _supported = false;
  bool _enabled = false;

  /// iOS 26 أو أحدث.
  bool get supported => _supported;

  /// مفعل ومسموح: التذكيرات تُجدول كمنبهات نظام بدل الإشعارات.
  bool get active => _supported && _enabled;

  Future<void> init() async {
    try {
      _supported = await _kit.isSupported();
      if (!_supported) return;
      final wanted =
          (await SharedPreferences.getInstance()).getBool(kEnabled) ?? false;
      _enabled = wanted && await _authorized();
    } catch (e) {
      debugPrint('AlarmKit init failed: $e');
      _supported = false;
    }
  }

  Future<bool> _authorized() async =>
      await _kit.authorizationState() == AlarmAuthorization.authorized;

  /// تفعيل/إيقاف. يعيد false إذا رفض المستخدم الإذن.
  Future<bool> setEnabled(bool v) async {
    if (!_supported) return false;
    if (v) {
      final auth = await _kit.requestAuthorization();
      if (auth != AlarmAuthorization.authorized) return false;
    } else {
      await cancelAll();
    }
    _enabled = v;
    await (await SharedPreferences.getInstance()).setBool(kEnabled, v);
    return true;
  }

  /// معرّف ثابت لكل تذكير (نفس التذكير = نفس المنبه، فإعادة الجدولة تستبدله).
  static String alarmId(int notifId) =>
      const Uuid().v5(Namespace.url.value, 'mysecretary:alarm:$notifId');

  Future<bool> schedule({
    required int notifId,
    required String title,
    required DateTime at,
    required bool isEvent,
  }) async {
    if (!active) return false;
    try {
      await _kit.scheduleAlarm(
        id: alarmId(notifId),
        schedule: AlarmSchedule.fixed(at),
        tint: isEvent ? const Color(0xFFFF3B30) : const Color(0xFFFF9500),
        postAlert: snooze,
        presentation: AlarmPresentation(
          alert: AlarmAlert(
            title: title,
            stopButton: const AlarmButton(
              text: 'إيقاف',
              systemImageName: 'stop.fill',
            ),
            secondaryButton: const AlarmButton(
              text: 'تأجيل 10 دقائق',
              systemImageName: 'zzz',
            ),
            secondaryBehavior: AlarmSecondaryBehavior.countdown,
          ),
          countdown: AlarmCountdown(title: 'مؤجل: $title'),
        ),
      );
      return true;
    } catch (e) {
      // مثلاً عند تجاوز الحد الأقصى للمنبهات: نرجع للإشعار العادي
      debugPrint('AlarmKit schedule failed: $e');
      return false;
    }
  }

  Future<void> cancel(int notifId) async {
    if (!_supported) return;
    try {
      await _kit.cancel(alarmId(notifId));
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      for (final a in await _kit.alarms()) {
        await _kit.cancel(a.id);
      }
    } catch (_) {}
  }
}
