import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../services/backup_service.dart';

/// النسخ الاحتياطي: الحفظ في تطبيق الملفات، المشاركة، الاستعادة، وتصدير CSV.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  DateTime? _last;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    BackupService.lastBackup().then((v) {
      if (mounted) setState(() => _last = v);
    });
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } on BackupException catch (e) {
      if (mounted) await infoDialog(context, 'تعذّرت العملية', e.message);
    } catch (e) {
      if (mounted) await infoDialog(context, 'حدث خطأ', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// حفظ الملف عبر نافذة النظام (تطبيق "الملفات" على iPhone).
  Future<bool> _saveFile(String name, Uint8List bytes, String mime) async {
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: mime,
    );
    return uri != null;
  }

  /// مشاركة الملف (AirDrop، واتساب، البريد، "حفظ في الملفات"...).
  Future<void> _share(String name, Uint8List bytes, String mime) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime, name: name)],
        fileNameOverrides: [name],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _backupToFiles() => _run(() async {
    final bytes = await BackupService.exportBytes();
    if (await _saveFile(
      BackupService.backupFileName(),
      bytes,
      'application/json',
    )) {
      await BackupService.markBackedUp();
      setState(() => _last = DateTime.now());
      if (mounted) toast(context, 'تم حفظ النسخة الاحتياطية ✓');
    }
  });

  Future<void> _backupShare() => _run(() async {
    final bytes = await BackupService.exportBytes();
    await _share(BackupService.backupFileName(), bytes, 'application/json');
    await BackupService.markBackedUp();
    setState(() => _last = DateTime.now());
  });

  Future<void> _csv(String kind) => _run(() async {
    final bytes = kind == 'expenses'
        ? await BackupService.transactionsCsv()
        : await BackupService.estateCsv();
    final name = BackupService.csvFileName(kind);
    if (!mounted) return;
    await showActionSheet(context, [
      SheetAction('حفظ في الملفات', () async {
        if (await _saveFile(name, bytes, 'text/csv') && mounted) {
          toast(context, 'تم حفظ الملف ✓');
        }
      }, icon: CupertinoIcons.folder),
      SheetAction(
        'مشاركة',
        () => _share(name, bytes, 'text/csv'),
        icon: CupertinoIcons.share,
      ),
    ]);
  });

  Future<void> _restore() => _run(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    final info = BackupService.parse(await file.readAsBytes());
    if (!mounted) return;

    final summary = [
      if (info.exportedAt != null)
        'تاريخ النسخة: ${Fmt.dateTime(info.exportedAt!)}',
      for (final t in [
        'tasks',
        'events',
        'notes',
        'transactions',
        'estates',
        'heirs',
        'estate_entries',
      ])
        '${BackupService.tableLabels[t]}: ${info.count(t)}',
    ].join('\n');
    final ok = await confirmDialog(
      context,
      '$summary\n\nسيتم استبدال جميع بياناتك الحالية بمحتوى هذه النسخة. لا يمكن التراجع عن ذلك.',
      ok: 'استعادة',
    );
    if (!ok) return;

    await BackupService.restore(info);
    _refreshAll();
    if (mounted) {
      await infoDialog(
        context,
        'تمت الاستعادة ✓',
        'تمت استعادة جميع البيانات بنجاح.',
      );
    }
  });

  void _refreshAll() {
    ref.invalidate(tasksProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(notesProvider);
    ref.invalidate(themeModeProvider);
    refreshFinance(ref);
    refreshEstate(ref);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          children: [
            const Center(
              child: IconBadge(
                CupertinoIcons.cloud_upload_fill,
                IosColors.blue,
                size: 64,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 22),
              child: Column(
                children: [
                  Text(
                    'احفظ نسخة من جميع بياناتك (المهام، المواعيد، الملاحظات، المصاريف، حسابات الورثة والإعدادات) '
                    'في ملف واحد، واستعدها في أي وقت أو على جهاز آخر.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Ios.secondary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _last == null
                        ? 'لم تُنشأ نسخة احتياطية بعد'
                        : 'آخر نسخة: ${Fmt.dateTime(_last!)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _last == null ? IosColors.orange : IosColors.green,
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: CupertinoActivityIndicator(),
                    ),
                ],
              ),
            ),
            IosSection(
              header: 'نسخة احتياطية كاملة',
              footer: 'يُنصح بحفظ النسخة في iCloud Drive من تطبيق الملفات لتبقى آمنة حتى لو فُقد الجوال.',
              dividerIndent: 60,
              children: [
                IosTile(
                  leading: const IconBadge(
                    CupertinoIcons.folder_fill,
                    IosColors.blue,
                  ),
                  title: 'حفظ في الملفات',
                  subtitle: 'iCloud Drive أو على الجهاز',
                  chevron: true,
                  onTap: _backupToFiles,
                ),
                IosTile(
                  leading: const IconBadge(
                    CupertinoIcons.share,
                    IosColors.green,
                  ),
                  title: 'مشاركة النسخة',
                  subtitle: 'AirDrop، واتساب، البريد...',
                  chevron: true,
                  onTap: _backupShare,
                ),
              ],
            ),
            IosSection(
              header: 'تصدير إلى Excel',
              footer: 'ملفات CSV تفتح في Excel و Numbers و Google Sheets.',
              dividerIndent: 60,
              children: [
                IosTile(
                  leading: const IconBadge(
                    CupertinoIcons.creditcard_fill,
                    IosColors.orange,
                  ),
                  title: 'العمليات المالية',
                  chevron: true,
                  onTap: () => _csv('expenses'),
                ),
                IosTile(
                  leading: const IconBadge(
                    CupertinoIcons.person_3_fill,
                    IosColors.indigo,
                  ),
                  title: 'حركات حسابات الورثة',
                  chevron: true,
                  onTap: () => _csv('estates'),
                ),
              ],
            ),
            IosSection(
              header: 'الاستعادة',
              footer: 'اختر ملف النسخة الاحتياطية (.json). ستُستبدل البيانات الحالية بالكامل.',
              children: [
                IosTile(
                  leading: const IconBadge(
                    CupertinoIcons.arrow_counterclockwise,
                    IosColors.red,
                  ),
                  title: 'استعادة من ملف',
                  chevron: true,
                  onTap: _restore,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
