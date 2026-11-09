import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'estate/estates_screen.dart';
import 'expenses/categories_screen.dart';
import 'expenses/sms_settings_screen.dart';
import 'notes/notes_screen.dart';
import 'settings/backup_screen.dart';
import 'settings/settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, Color c, String t, String s, Widget page) =>
        IosTile(
          leading: IconBadge(i, c),
          title: t,
          subtitle: s,
          chevron: true,
          onTap: () => Navigator.push(context, iosRoute(page)),
        );
    return Scaffold(
      appBar: largeTitleBar(context, 'المزيد'),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          IosSection(
            dividerIndent: 60,
            children: [
              tile(
                CupertinoIcons.doc_text_fill,
                IosColors.yellow,
                'الملاحظات',
                'ملاحظات سريعة ملونة',
                const NotesScreen(),
              ),
              tile(
                CupertinoIcons.person_3_fill,
                IosColors.indigo,
                'حسابات الورثة',
                'إيرادات ومصروفات التركة وأنصبة الورثة',
                const EstatesScreen(),
              ),
            ],
          ),
          IosSection(
            header: 'المصاريف',
            dividerIndent: 60,
            children: [
              tile(
                CupertinoIcons.chat_bubble_text_fill,
                IosColors.green,
                'رسائل البنوك',
                'التسجيل التلقائي للمصروفات من الرسائل',
                const SmsSettingsScreen(),
              ),
              tile(
                CupertinoIcons.square_grid_2x2_fill,
                IosColors.orange,
                'التصنيفات والميزانية',
                'إدارة التصنيفات وحدود الصرف الشهرية',
                const CategoriesScreen(),
              ),
            ],
          ),
          IosSection(
            dividerIndent: 60,
            children: [
              tile(
                CupertinoIcons.cloud_upload_fill,
                IosColors.blue,
                'النسخ الاحتياطي',
                'حفظ البيانات في الملفات واستعادتها',
                const BackupScreen(),
              ),
              tile(
                CupertinoIcons.gear_solid,
                IosColors.gray,
                'الإعدادات',
                'المظهر وعن التطبيق',
                const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
