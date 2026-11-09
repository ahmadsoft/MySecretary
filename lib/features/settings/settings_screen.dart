import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';

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
                value: '1.2.0',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
