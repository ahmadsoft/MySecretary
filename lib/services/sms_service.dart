import 'dart:io';
import 'dart:ui';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'notification_service.dart';
import 'sms_parser.dart';

/// يستقبل رسائل البنوك على أندرويد ويسجلها كمصروفات/إيرادات تلقائياً.
/// ملاحظة: نظام iOS لا يسمح لأي تطبيق بقراءة الرسائل، لذلك نوفر على iOS
/// خيار "لصق رسالة البنك" بدلاً من ذلك.
class SmsService {
  SmsService._();
  static final instance = SmsService._();

  static const kEnabled = 'sms_enabled';
  static const kSenders = 'sms_senders';
  static const kLastSync = 'sms_last_sync';
  static const kNotify = 'sms_notify';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// يُستدعى بعد كل تسجيل جديد لتحديث الواجهة.
  VoidCallback? onRecorded;

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(kEnabled) ?? false;

  Future<List<String>> senders() async =>
      (await SharedPreferences.getInstance()).getStringList(kSenders) ?? [];

  Future<void> setSenders(List<String> s) async =>
      (await SharedPreferences.getInstance()).setStringList(kSenders, s);

  Future<bool> notifyEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(kNotify) ?? true;

  Future<void> setNotify(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(kNotify, v);

  /// تفعيل/إيقاف القراءة التلقائية. يعيد false إذا رُفض الإذن.
  Future<bool> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    if (v) {
      if (!supported) return false;
      final st = await Permission.sms.request();
      if (!st.isGranted) return false;
      await prefs.setBool(kEnabled, true);
      await start();
    } else {
      await prefs.setBool(kEnabled, false);
    }
    return true;
  }

  /// يبدأ الاستماع للرسائل الجديدة ويزامن صندوق الوارد.
  Future<void> start() async {
    if (!supported || !await isEnabled()) return;
    if (!await Permission.sms.isGranted) return;
    try {
      Telephony.instance.listenIncomingSms(
        onNewMessage: (m) async {
          final r = await handleMessage(
            m.address ?? '',
            m.body ?? '',
            m.date ?? DateTime.now().millisecondsSinceEpoch,
          );
          if (r) onRecorded?.call();
        },
        onBackgroundMessage: smsBackgroundHandler,
      );
    } catch (e) {
      debugPrint('SMS listen failed: $e');
    }
    await syncInbox();
  }

  /// يقرأ الرسائل منذ آخر مزامنة (أول مرة: آخر 30 يوماً). يعيد عدد العمليات المسجلة.
  Future<int> syncInbox({int firstDays = 30}) async {
    if (!supported || !await isEnabled()) return 0;
    if (!await Permission.sms.isGranted) return 0;
    final prefs = await SharedPreferences.getInstance();
    final last =
        prefs.getInt(kLastSync) ??
        DateTime.now()
            .subtract(Duration(days: firstDays))
            .millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    var count = 0;
    try {
      final msgs = await Telephony.instance.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan('$last'),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
      );
      for (final m in msgs) {
        if (await handleMessage(
          m.address ?? '',
          m.body ?? '',
          m.date ?? now,
          notify: false,
        )) {
          count++;
        }
      }
      await prefs.setInt(kLastSync, now);
    } catch (e) {
      debugPrint('SMS sync failed: $e');
    }
    if (count > 0) onRecorded?.call();
    return count;
  }

  /// يحلل رسالة ويسجلها إذا كانت عملية بنكية. يعيد true عند التسجيل.
  Future<bool> handleMessage(
    String sender,
    String body,
    int dateMs, {
    bool notify = true,
  }) async {
    final allowed = await senders();
    if (allowed.isNotEmpty &&
        !allowed.any((s) => sender.toLowerCase().contains(s.toLowerCase()))) {
      return false;
    }
    final tx = await recordFromText(
      body,
      sender: sender,
      date: DateTime.fromMillisecondsSinceEpoch(dateMs),
    );
    if (tx == null) return false;
    if (notify && await notifyEnabled()) {
      final kind = tx.kind == TxKind.expense ? 'مصروف' : 'إيراد';
      await NotificationService.instance.showSmsRecorded(
        tx.id!,
        'تم تسجيل $kind ${Fmt.money(tx.amount)}',
        tx.merchant.isEmpty ? 'من رسالة $sender' : tx.merchant,
      );
    }
    return true;
  }

  /// يسجل عملية من نص رسالة (يستخدم أيضاً لميزة اللصق على iOS).
  Future<Tx?> recordFromText(
    String body, {
    String sender = 'manual',
    DateTime? date,
  }) async {
    final parsed = SmsParser.parse(body);
    if (parsed == null) return null;
    final d = date ?? DateTime.now();
    final hash = SmsParser.hash(
      sender,
      sender == 'manual' ? 0 : d.millisecondsSinceEpoch,
      body,
    );
    final repo = FinanceRepo();
    if (await repo.smsExists(hash)) return null;
    final cat = await repo.suggestCategory(
      parsed.merchant,
      parsed.kind,
      parsed.method,
    );
    final tx = Tx(
      kind: parsed.kind,
      amount: parsed.amount,
      categoryId: cat,
      merchant: parsed.merchant,
      date: d,
      method: parsed.method,
      fromSms: true,
      smsHash: hash,
      rawSms: body,
    );
    final id = await repo.saveTx(tx, learnRule: false);
    return Tx.fromMap(tx.toMap()..['id'] = id);
  }
}

/// يعمل عند وصول رسالة والتطبيق مغلق أو في الخلفية.
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage m) async {
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.instance.init(requestPermission: false);
  await SmsService.instance.handleMessage(
    m.address ?? '',
    m.body ?? '',
    m.date ?? DateTime.now().millisecondsSinceEpoch,
  );
}
