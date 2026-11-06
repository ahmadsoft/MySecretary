import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
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
      appBar: AppBar(title: const Text('حسابات الورثة')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => editEstate(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('حساب تركة جديد'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.family_restroom,
                message: 'أنشئ حساباً للتركة لتسجيل الإيرادات والمصروفات وتوزيع أنصبة الورثة',
              )
            : ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                children: [for (final e in list) _EstateCard(estate: e)],
              ),
      ),
    );
  }
}

class _EstateCard extends ConsumerWidget {
  final Estate estate;
  const _EstateCard({required this.estate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(estateDataProvider(estate.id!)).value;
    final s = data?.summary;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: const CircleAvatar(child: Icon(Icons.account_balance)),
        title: Text(
          estate.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: s == null
            ? null
            : Text(
                '${data!.heirs.length} ورثة • الرصيد المتبقي: ${Fmt.money(s.cashBalance)}',
              ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EstateDetailScreen(estateId: estate.id!),
          ),
        ),
      ),
    );
  }
}

Future<void> editEstate(BuildContext context, WidgetRef ref, Estate? e) async {
  final name = TextEditingController(text: e?.name);
  final deceased = TextEditingController(text: e?.deceasedName);
  final notes = TextEditingController(text: e?.notes);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(e == null ? 'حساب تركة جديد' : 'تعديل الحساب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم الحساب',
                hintText: 'مثال: تركة الوالد',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: deceased,
              decoration: const InputDecoration(
                labelText: 'اسم المتوفى رحمه الله',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حفظ'),
        ),
      ],
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
