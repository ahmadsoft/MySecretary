import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../services/notification_service.dart';
import '../alarm/alarm_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    Widget option(ThemeMode m, String label) => IosTile(
      title: label,
      trailing: mode == m
          ? Icon(CupertinoIcons.checkmark_alt, color: Ios.tint(context))
          : null,
      onTap: () => ref.read(themeModeProvider.notifier).set(m),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          IosSection(
            header: 'المظهر',
            children: [
              option(ThemeMode.system, 'حسب إعدادات الجهاز'),
              option(ThemeMode.light, 'فاتح'),
              option(ThemeMode.dark, 'داكن'),
            ],
          ),
          const _AlarmSettings(),
          const IosSection(
            dividerIndent: 60,
            footer: 'جميع بياناتك محفوظة محلياً على جهازك فقط ولا تُرسل إلى أي خادم.',
            children: [
              IosTile(
                leading: IconBadge(CupertinoIcons.lock_fill, IosColors.blue),
                title: 'الخصوصية',
                value: 'محلي',
              ),
              IosTile(
                leading: IconBadge(CupertinoIcons.info, IosColors.gray),
                title: 'الإصدار',
                value: '1.4.0',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// إعدادات تنبيه المهام والمواعيد بملء الشاشة.
class _AlarmSettings extends StatefulWidget {
  const _AlarmSettings();

  @override
  State<_AlarmSettings> createState() => _AlarmSettingsState();
}

class _AlarmSettingsState extends State<_AlarmSettings> {
  final n = NotificationService.instance;

  @override
  Widget build(BuildContext context) {
    return IosSection(
      header: 'التنبيهات',
      footer: n.alarmMode
          ? 'تظهر تذكيرات المهام والمواعيد بملء الشاشة مع صوت مستمر، '
                'ويمكنك إيقافها أو تأجيلها ${NotificationService.snoozeMinutes} دقائق. '
                'جرّب "منبه بعد 10 ثوانٍ" ثم أقفل الجوال لترى الشكل على شاشة القفل.'
          : 'تظهر التذكيرات كإشعارات عادية.',
      dividerIndent: 60,
      children: [
        IosTile(
          leading: const IconBadge(alarmIcon, IosColors.orange),
          title: 'تنبيه بملء الشاشة (منبه)',
          trailing: IosSwitch(
            value: n.alarmMode,
            onChanged: (v) async {
              await n.setAlarmMode(v);
              setState(() {});
            },
          ),
        ),
        if (n.alarmMode) ...[
          IosTile(
            leading: const IconBadge(CupertinoIcons.play_fill, IosColors.green),
            title: 'تجربة المنبه الآن',
            chevron: true,
            onTap: showTestAlarm,
          ),
          IosTile(
            leading: const IconBadge(CupertinoIcons.timer, IosColors.indigo),
            title: 'منبه تجريبي بعد 10 ثوانٍ',
            subtitle: 'أقفل الجوال بعد الضغط',
            chevron: true,
            onTap: () async {
              await n.scheduleTest(const Duration(seconds: 10));
              if (context.mounted) {
                toast(context, 'سيرن المنبه بعد 10 ثوانٍ، أقفل الجوال الآن');
              }
            },
          ),
        ],
      ],
    );
  }
}
