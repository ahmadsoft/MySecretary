import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'المظهر',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
            child: const Column(
              children: [
                RadioListTile(
                  value: ThemeMode.system,
                  title: Text('حسب إعدادات الجهاز'),
                ),
                RadioListTile(value: ThemeMode.light, title: Text('فاتح')),
                RadioListTile(value: ThemeMode.dark, title: Text('داكن')),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('الخصوصية'),
            subtitle: Text(
              'جميع بياناتك محفوظة محلياً على جهازك فقط ولا تُرسل إلى أي خادم.',
            ),
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'سكرتيري',
            applicationVersion: '1.0.0',
            applicationLegalese: 'مساعدك الشخصي لتنظيم المهام والمواعيد والمصاريف وحسابات الورثة.',
          ),
        ],
      ),
    );
  }
}
