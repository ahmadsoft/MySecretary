import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/notification_service.dart';
import '../settings/privacy_policy_screen.dart';

/// صفحة توضيحية موحدة تظهر قبل طلب أي إذن حساس.
class _ConsentSheet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String intro;
  final List<(IconData, String)> points;
  final String accept;
  final String decline;
  const _ConsentSheet({
    required this.icon,
    required this.color,
    required this.title,
    required this.intro,
    required this.points,
    required this.accept,
    required this.decline,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon, color, size: 68),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Ios.label(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              intro,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Ios.secondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            for (final (i, t) in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(i, color: color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => openPrivacyPolicy(context),
              child: const Text(
                'اقرأ سياسة الخصوصية',
                style: TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(accept),
            ),
            const SizedBox(height: 6),
            CupertinoButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(decline),
            ),
          ],
        ),
      ),
    );
  }
}

/// الإفصاح الواضح (Prominent Disclosure) المطلوب من Google Play قبل طلب إذن الرسائل:
/// ما الذي يُقرأ، ولماذا، وأين يُحفظ — ولا يُطلب الإذن إلا بعد الموافقة الصريحة.
Future<bool> showSmsProminentDisclosure(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _ConsentSheet(
      icon: CupertinoIcons.chat_bubble_text_fill,
      color: IosColors.green,
      title: 'قراءة رسائل البنوك',
      intro: 'يحتاج سكرتيري إذن قراءة الرسائل النصية واستقبالها لتسجيل مصروفاتك وإيراداتك تلقائياً من رسائل البنك.',
      points: [
        (
          CupertinoIcons.doc_text_search,
          'يقرأ التطبيق الرسائل الواردة ويبحث فيها عن عمليات بنكية (المبلغ، نوع العملية، الجهة).',
        ),
        (
          CupertinoIcons.device_phone_portrait,
          'التحليل يتم على جهازك فقط، ولا تُرسل أي رسالة أو بيانات إلى أي خادم أو جهة.',
        ),
        (
          CupertinoIcons.tray_arrow_down_fill,
          'يُحفظ على جهازك المبلغ والجهة ونص رسالة البنك التي سُجلت منها العملية فقط.',
        ),
        (
          CupertinoIcons.lock_fill,
          'رسائل رموز التحقق والرسائل الشخصية تُتجاهل ولا تُحفظ.',
        ),
        (
          CupertinoIcons.power,
          'يمكنك إيقاف الميزة في أي وقت من: المزيد ← رسائل البنوك.',
        ),
      ],
      accept: 'أوافق، متابعة',
      decline: 'ليس الآن',
    ),
  );
  final accepted = ok ?? false;
  await (await SharedPreferences.getInstance()).setBool(
    'sms_consent',
    accepted,
  );
  return accepted;
}

/// شرح سبب إذن الإشعارات قبل طلبه (أول تشغيل فقط).
Future<void> showPermissionRationale(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('notif_rationale_shown') ?? false) return;
  if (!context.mounted) return;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _ConsentSheet(
      icon: CupertinoIcons.bell_fill,
      color: IosColors.orange,
      title: 'تذكيرات في وقتها',
      intro: 'ليصلك تنبيه المهام والمواعيد في وقتها — حتى والتطبيق مغلق — يحتاج سكرتيري إذن الإشعارات.',
      points: [
        (
          CupertinoIcons.alarm_fill,
          'منبه بملء الشاشة مع "إيقاف" و"تأجيل 10 دقائق".',
        ),
        (
          CupertinoIcons.device_phone_portrait,
          'التذكيرات تُجدول على جهازك فقط.',
        ),
        (CupertinoIcons.gear, 'يمكنك تغيير ذلك لاحقاً من الإعدادات.'),
      ],
      accept: 'متابعة',
      decline: 'لاحقاً',
    ),
  );
  await prefs.setBool('notif_rationale_shown', true);
  if (ok == true) await NotificationService.instance.requestPermissions();
}

/// حالة إذن الإشعارات (لعرضها في الإعدادات).
Future<bool> notificationsAllowed() async {
  try {
    return await Permission.notification.isGranted;
  } catch (_) {
    return true;
  }
}

/// عند رفض إذن سابقاً: شرح الحل وفتح إعدادات النظام.
Future<void> explainDeniedPermission(BuildContext context, String what) async {
  final open = await confirmDialog(
    context,
    'إذن $what مرفوض حالياً. يمكنك السماح به من إعدادات الجهاز ← سكرتيري.',
    ok: 'فتح الإعدادات',
    destructive: false,
  );
  if (open) await openAppSettings();
}
