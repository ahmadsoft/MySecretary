import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'estate_detail_screen.dart';

class EstatesScreen extends ConsumerWidget {
  const EstatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(estatesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابات الورثة'),
        actions: [
          NavIcon(
            CupertinoIcons.add,
            tooltip: 'حساب جديد',
            onPressed: () => editEstate(context, ref, null),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmptyState(
                    icon: CupertinoIcons.person_3,
                    message: 'أنشئ حساباً للتركة لتسجيل الإيرادات والمصروفات وتوزيع أنصبة الورثة',
                  ),
                  CupertinoButton.filled(
                    onPressed: () => editEstate(context, ref, null),
                    child: const Text('إنشاء حساب'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: 12),
                children: [
                  IosSection(
                    dividerIndent: 70,
                    children: [for (final e in list) _EstateRow(estate: e)],
                  ),
                ],
              ),
      ),
    );
  }
}

class _EstateRow extends ConsumerWidget {
  final Estate estate;
  const _EstateRow({required this.estate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(estateDataProvider(estate.id!)).value;
    return IosTile(
      leading: const IconBadge(
        CupertinoIcons.building_2_fill,
        IosColors.indigo,
        size: 40,
      ),
      title: estate.name,
      bold: true,
      subtitle: data == null
          ? null
          : '${data.heirs.length} ورثة · الرصيد ${Fmt.money(data.summary.cashBalance)}',
      chevron: true,
      onTap: () => Navigator.push(
        context,
        iosRoute(EstateDetailScreen(estateId: estate.id!)),
      ),
    );
  }
}

Future<void> editEstate(BuildContext context, WidgetRef ref, Estate? e) async {
  final name = TextEditingController(text: e?.name);
  final deceased = TextEditingController(text: e?.deceasedName);
  final notes = TextEditingController(text: e?.notes);
  final ok = await showIosSheet<bool>(
    context,
    Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (ctx) => SheetHeader(
              title: e == null ? 'حساب تركة جديد' : 'تعديل الحساب',
              onSave: () => Navigator.pop(ctx, true),
            ),
          ),
          const SizedBox(height: 8),
          IosSection(
            footer: 'مثال: تركة الوالد رحمه الله',
            children: [
              IosField(name, 'اسم الحساب', autofocus: true),
              IosField(deceased, 'اسم المتوفى'),
              IosField(notes, 'ملاحظات', maxLines: 3),
            ],
          ),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  await estateRepo.saveEstate(
    Estate(
      id: e?.id,
      name: name.text.trim(),
      deceasedName: deceased.text.trim(),
      notes: notes.text.trim(),
      createdAt: e?.createdAt,
    ),
  );
  refreshEstate(ref, e?.id);
}
