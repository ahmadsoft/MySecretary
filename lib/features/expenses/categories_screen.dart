import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    Widget section(String title, TxKind kind) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        for (final c in cats.where((c) => c.kind == kind))
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(c.color).withValues(alpha: 0.15),
                child: Icon(iconAt(c.icon), color: Color(c.color)),
              ),
              title: Text(c.name),
              subtitle: (c.monthlyBudget ?? 0) > 0
                  ? Text('الميزانية الشهرية: ${Fmt.money(c.monthlyBudget!)}')
                  : null,
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _edit(context, ref, c, kind),
            ),
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('التصنيفات والميزانية')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(context, ref, null, TxKind.expense),
        icon: const Icon(Icons.add),
        label: const Text('تصنيف جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          section('تصنيفات المصروفات', TxKind.expense),
          section('تصنيفات الإيرادات', TxKind.income),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Category? c,
    TxKind kind,
  ) async {
    final name = TextEditingController(text: c?.name);
    final budget = TextEditingController(
      text: (c?.monthlyBudget ?? 0) > 0
          ? c!.monthlyBudget!.toStringAsFixed(0)
          : '',
    );
    var icon = c?.icon ?? iconIndex(Icons.category);
    var color = c?.color ?? AppTheme.palette.first.toARGB32();
    var k = c?.kind ?? kind;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c == null ? 'تصنيف جديد' : 'تعديل التصنيف',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (c == null)
                  SegmentedButton<TxKind>(
                    segments: const [
                      ButtonSegment(
                        value: TxKind.expense,
                        label: Text('مصروف'),
                      ),
                      ButtonSegment(value: TxKind.income, label: Text('إيراد')),
                    ],
                    selected: {k},
                    onSelectionChanged: (s) => setS(() => k = s.first),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 12),
                if (k == TxKind.expense)
                  TextField(
                    controller: budget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الميزانية الشهرية (اختياري)',
                      suffixText: 'ر.س',
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < categoryIcons.length; i++)
                      IconButton.filledTonal(
                        isSelected: i == icon,
                        icon: Icon(
                          categoryIcons[i],
                          color: i == icon ? Color(color) : null,
                        ),
                        onPressed: () => setS(() => icon = i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final p in AppTheme.palette)
                      GestureDetector(
                        onTap: () => setS(() => color = p.toARGB32()),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: p,
                          child: p.toARGB32() == color
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (c != null)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف'),
                        onPressed: () async {
                          if (await confirmDialog(
                            ctx,
                            'حذف التصنيف؟ ستبقى العمليات بدون تصنيف.',
                          )) {
                            await financeRepo.deleteCategory(c.id!);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          }
                        },
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        await financeRepo.saveCategory(
                          Category(
                            id: c?.id,
                            name: name.text.trim(),
                            icon: icon,
                            color: color,
                            kind: k,
                            monthlyBudget: k == TxKind.expense
                                ? Fmt.parseAmount(budget.text)
                                : null,
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) refreshFinance(ref);
  }
}
