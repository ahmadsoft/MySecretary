import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// سياسة الخصوصية داخل التطبيق (نفس محتوى docs/privacy-policy.md).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const updated = '18 نوفمبر 2026';

  @override
  Widget build(BuildContext context) {
    Widget section(
      String title,
      List<String> lines, {
      IconData? icon,
      Color? color,
    }) => IosSection(
      header: title,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(
                          icon ?? CupertinoIcons.checkmark_alt,
                          size: 16,
                          color: color ?? IosColors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l,
                          style: const TextStyle(fontSize: 15, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        children: [
          const Center(
            child: IconBadge(
              CupertinoIcons.lock_shield_fill,
              IosColors.blue,
              size: 64,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 20),
            child: Text(
              'سكرتيري لا يجمع أي بيانات. كل شيء محفوظ على جهازك فقط.\nآخر تحديث: $updated',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Ios.secondary(context)),
            ),
          ),
          section('الخلاصة', const [
            'لا يوجد خادم ولا حساب ولا تسجيل دخول.',
            'كل بياناتك (المهام، المواعيد، الملاحظات، المصاريف، حسابات الورثة) محفوظة على جهازك فقط.',
            'لا إعلانات، ولا تتبع، ولا مشاركة مع أي طرف ثالث.',
          ]),
          section(
            'رسائل البنوك (أندرويد فقط، باختيارك)',
            const [
              'الميزة معطلة افتراضياً، ولا تعمل إلا بعد موافقتك على شاشة التوضيح ثم منح الإذن.',
              'تُحلَّل الرسائل على جهازك فقط لتسجيل المصروفات والإيرادات.',
              'يُحفظ المبلغ ونوع العملية والجهة ونص الرسالة البنكية التي سُجلت منها العملية.',
              'رسائل رموز التحقق والرسائل غير المالية تُتجاهل ولا تُحفظ.',
              'يمكنك إيقافها في أي وقت من: المزيد ← رسائل البنوك.',
              'على iPhone لا يقرأ التطبيق الرسائل إطلاقاً.',
            ],
            icon: CupertinoIcons.chat_bubble_text_fill,
            color: IosColors.green,
          ),
          section(
            'الإشعارات والمنبه',
            const [
              'تُجدول التذكيرات محلياً عبر نظام التشغيل.',
              'على iOS 26 يمكن استخدام منبه النظام بموافقتك، ويحتفظ النظام بعنوان التذكير ووقته لعرض المنبه.',
            ],
            icon: CupertinoIcons.bell_fill,
            color: IosColors.orange,
          ),
          section(
            'النسخ الاحتياطي والتصدير',
            const [
              'يُنشأ ملف النسخة أو CSV فقط عندما تطلبه أنت، ويُحفظ أو يُرسل إلى المكان الذي تختاره.',
              'لا يرسل التطبيق أي ملف تلقائياً.',
            ],
            icon: CupertinoIcons.folder_fill,
            color: IosColors.blue,
          ),
          section(
            'حذف البيانات',
            const [
              'حذف التطبيق يحذف جميع بياناته نهائياً من جهازك، ولا توجد لدينا أي نسخة منها.',
            ],
            icon: CupertinoIcons.trash_fill,
            color: IosColors.red,
          ),
          section(
            'الأطفال',
            const [
              'التطبيق غير موجه للأطفال دون 13 عاماً ولا يجمع بيانات من أي شخص.',
            ],
            icon: CupertinoIcons.info_circle_fill,
            color: IosColors.gray,
          ),
        ],
      ),
    );
  }
}

/// فتح سياسة الخصوصية من أي مكان.
void openPrivacyPolicy(BuildContext context) =>
    Navigator.push(context, iosRoute(const PrivacyPolicyScreen()));
