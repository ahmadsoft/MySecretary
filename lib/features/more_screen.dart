import 'package:flutter/material.dart';

import 'estate/estates_screen.dart';
import 'expenses/categories_screen.dart';
import 'expenses/sms_settings_screen.dart';
import 'notes/notes_screen.dart';
import 'settings/settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String t, String s, Widget page) => Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(i)),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(s),
        trailing: const Icon(Icons.chevron_left),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          tile(
            Icons.sticky_note_2,
            'الملاحظات',
            'ملاحظات سريعة ملونة',
            const NotesScreen(),
          ),
          tile(
            Icons.family_restroom,
            'حسابات الورثة',
            'إيرادات ومصروفات التركة وأنصبة الورثة',
            const EstatesScreen(),
          ),
          tile(
            Icons.sms,
            'رسائل البنوك',
            'التسجيل التلقائي للمصروفات من الرسائل',
            const SmsSettingsScreen(),
          ),
          tile(
            Icons.category,
            'تصنيفات المصاريف والميزانية',
            'إدارة التصنيفات وحدود الصرف الشهرية',
            const CategoriesScreen(),
          ),
          tile(
            Icons.settings,
            'الإعدادات',
            'المظهر وعن التطبيق',
            const SettingsScreen(),
          ),
        ],
      ),
    );
  }
}
