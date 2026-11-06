import 'package:flutter/cupertino.dart';
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
    Widget section(String title, TxKind kind) => IosSection(
      header: title,
      dividerIndent: 60,
      children: [
        for (final c in cats.where((c) => c.kind == kind))
          IosTile(
            leading: IconBadge(iconAt(c.icon), Color(c.color)),
            title: c.name,
            value: (c.monthlyBudget ?? 0) > 0
                ? Fmt.money(c.monthlyBudget!)
                : null,
            chevron: true,
            onTap: () => _edit(context, ref, c, kind),
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('التصنيفات والميزانية'),
        actions: [
          NavIcon(
            CupertinoIcons.add,
            tooltip: 'تصنيف جديد',
            onPressed: () => _edit(context, ref, null, TxKind.expense),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
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
    var icon = c?.icon ?? 9;
    var color = c?.color ?? AppTheme.palette.first.toARGB32();
    var k = c?.kind ?? kind;

    final saved = await showIosSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> save() async {
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
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  title: c == null ? 'تصنيف جديد' : 'تعديل التصنيف',
                  onSave: save,
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Center(
                        child: IconBadge(iconAt(icon), Color(color), size: 72),
                      ),
                      const SizedBox(height: 18),
                      if (c == null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: IosSegmented<TxKind>(
                            items: const {
                              TxKind.expense: 'مصروف',
                              TxKind.income: 'إيراد',
                            },
                            value: k,
                            onChanged: (v) => setS(() => k = v),
                          ),
                        ),
                      IosSection(
                        children: [
                          IosField(name, 'اسم التصنيف'),
                          if (k == TxKind.expense)
                            IosField(
                              budget,
                              'الميزانية الشهرية (اختياري)',
                              keyboardType: TextInputType.number,
                              suffix: 'ر.س',
                            ),
                        ],
                      ),
                      IosSection(
                        header: 'اللون',
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final p in AppTheme.palette)
                                  GestureDetector(
                                    onTap: () =>
                                        setS(() => color = p.toARGB32()),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: p,
                                      child: p.toARGB32() == color
                                          ? const Icon(
                                              CupertinoIcons.checkmark_alt,
                                              size: 18,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IosSection(
                        header: 'الأيقونة',
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < categoryIcons.length; i++)
                                  GestureDetector(
                                    onTap: () => setS(() => icon = i),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: i == icon
                                            ? Color(color)
                                            : Ios.fill(ctx),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        categoryIcons[i],
                                        size: 22,
                                        color: i == icon
                                            ? Colors.white
                                            : Ios.secondary(ctx),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (c != null)
                        IosSection(
                          children: [
                            IosTile(
                              title: 'حذف التصنيف',
                              titleColor: IosColors.red,
                              onTap: () async {
                                if (await confirmDialog(
                                  ctx,
                                  'حذف التصنيف؟ ستبقى العمليات بدون تصنيف.',
                                )) {
                                  await financeRepo.deleteCategory(c.id!);
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (saved == true) refreshFinance(ref);
  }
}
