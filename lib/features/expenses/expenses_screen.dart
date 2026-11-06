import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../services/sms_service.dart';
import 'sms_settings_screen.dart';
import 'transaction_form.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txAsync = ref.watch(monthTxProvider(month));
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final catById = {for (final c in cats) c.id: c};

    return Scaffold(
      appBar: largeTitleBar(
        context,
        'المصاريف',
        actions: [
          NavIcon(
            CupertinoIcons.ellipsis_circle,
            tooltip: 'المزيد',
            onPressed: () {
              showActionSheet(context, [
                SheetAction(
                  'لصق رسالة بنك',
                  () => showPasteSmsDialog(context, ref),
                  icon: CupertinoIcons.doc_on_clipboard,
                ),
                if (SmsService.supported)
                  SheetAction(
                    'قراءة الرسائل الآن',
                    () => _sync(context, ref),
                    icon: CupertinoIcons.arrow_2_circlepath,
                  ),
                SheetAction(
                  'إعدادات رسائل البنوك',
                  () => Navigator.push(
                    context,
                    iosRoute(const SmsSettingsScreen()),
                  ),
                  icon: CupertinoIcons.chat_bubble_text,
                ),
              ]);
            },
          ),
          NavIcon(
            CupertinoIcons.add,
            tooltip: 'عملية جديدة',
            onPressed: () =>
                Navigator.push(context, iosRoute(const TransactionForm())),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (txs) => RefreshIndicator.adaptive(
          onRefresh: () async {
            await SmsService.instance.syncInbox();
            refreshFinance(ref);
          },
          child: _body(context, ref, month, txs, cats, catById),
        ),
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    if (!await SmsService.instance.isEnabled()) {
      if (context.mounted) {
        Navigator.push(context, iosRoute(const SmsSettingsScreen()));
      }
      return;
    }
    final n = await SmsService.instance.syncInbox();
    refreshFinance(ref);
    if (context.mounted) {
      toast(
        context,
        n == 0 ? 'لا توجد عمليات جديدة' : 'تم تسجيل $n عملية جديدة',
      );
    }
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
    List<Tx> txs,
    List<Category> cats,
    Map<int?, Category> catById,
  ) {
    final exp = txs.where((t) => t.kind == TxKind.expense);
    final totalExp = exp.fold(0.0, (s, t) => s + t.amount);
    final totalInc = txs
        .where((t) => t.kind == TxKind.income)
        .fold(0.0, (s, t) => s + t.amount);
    final byCat = <int?, double>{};
    for (final t in exp) {
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final budgets = cats.where(
      (c) => c.kind == TxKind.expense && (c.monthlyBudget ?? 0) > 0,
    );
    final groups = <DateTime, List<Tx>>{};
    for (final t in txs) {
      groups.putIfAbsent(Fmt.dayStart(t.date), () => []).add(t);
    }
    final n = ref.read(selectedMonthProvider.notifier);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // اختيار الشهر
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              CupertinoButton(
                child: const Icon(CupertinoIcons.chevron_right),
                onPressed: () => n.shift(-1),
              ),
              Expanded(
                child: Text(
                  Fmt.month(month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Ios.label(context),
                  ),
                ),
              ),
              CupertinoButton(
                child: const Icon(CupertinoIcons.chevron_left),
                onPressed: () => n.shift(1),
              ),
            ],
          ),
        ),
        // البطاقة الرئيسية
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Ios.cell(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إجمالي المصروفات',
                  style: TextStyle(fontSize: 15, color: Ios.secondary(context)),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    Fmt.money(totalExp),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Ios.label(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _mini(
                        context,
                        'الإيرادات',
                        totalInc,
                        IosColors.green,
                      ),
                    ),
                    Container(
                      width: 0.5,
                      height: 34,
                      color: Ios.separator(context),
                    ),
                    Expanded(
                      child: _mini(
                        context,
                        'الصافي',
                        totalInc - totalExp,
                        totalInc - totalExp >= 0
                            ? IosColors.green
                            : IosColors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (sorted.isNotEmpty)
          IosSection(
            header: 'توزيع المصروفات',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 34,
                          sections: [
                            for (final e in sorted)
                              PieChartSectionData(
                                value: e.value,
                                color: Color(
                                  catById[e.key]?.color ?? 0xFF8E8E93,
                                ),
                                radius: 22,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in sorted.take(5))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 4,
                                    backgroundColor: Color(
                                      catById[e.key]?.color ?? 0xFF8E8E93,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      catById[e.key]?.name ?? 'بدون تصنيف',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${(e.value / totalExp * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Ios.secondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (budgets.isNotEmpty)
          IosSection(
            header: 'الميزانية الشهرية',
            dividerIndent: 60,
            children: [
              for (final c in budgets)
                _BudgetRow(category: c, spent: byCat[c.id] ?? 0),
            ],
          ),
        if (txs.isEmpty)
          const SizedBox(
            height: 220,
            child: EmptyState(
              icon: CupertinoIcons.creditcard,
              message: 'لا توجد عمليات في هذا الشهر',
            ),
          ),
        for (final g in groups.entries)
          IosSection(
            header: '${Fmt.weekday(g.key)} ${Fmt.date(g.key)}',
            dividerIndent: 62,
            children: [
              for (final t in g.value)
                TxTile(tx: t, category: catById[t.categoryId]),
            ],
          ),
      ],
    );
  }

  Widget _mini(BuildContext context, String label, double v, Color color) =>
      Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Ios.secondary(context)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              Fmt.money(v),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      );
}

class _BudgetRow extends StatelessWidget {
  final Category category;
  final double spent;
  const _BudgetRow({required this.category, required this.spent});

  @override
  Widget build(BuildContext context) {
    final b = category.monthlyBudget!;
    final ratio = (spent / b).clamp(0.0, 1.0);
    final over = spent > b;
    final color = over
        ? IosColors.red
        : (ratio > 0.8 ? IosColors.orange : Color(category.color));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconBadge(iconAt(category.icon), Color(category.color)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${Fmt.money(spent)} من ${Fmt.money(b)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Ios.secondary(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: ratio,
                  color: color,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                if (over)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'تجاوزت الميزانية بـ ${Fmt.money(spent - b)}',
                      style: const TextStyle(
                        color: IosColors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صف عملية مالية (مثل تطبيق Wallet).
class TxTile extends StatelessWidget {
  final Tx tx;
  final Category? category;
  const TxTile({super.key, required this.tx, this.category});

  @override
  Widget build(BuildContext context) {
    final isExp = tx.kind == TxKind.expense;
    final color = Color(category?.color ?? 0xFF8E8E93);
    return IosTile(
      leading: IconBadge(iconAt(category?.icon ?? -1), color, size: 34),
      title: tx.merchant.isNotEmpty
          ? tx.merchant
          : (category?.name ?? 'بدون تصنيف'),
      subtitleWidget: Row(
        children: [
          Flexible(
            child: Text(
              '${category?.name ?? 'بدون تصنيف'} · ${paymentLabels[tx.method]}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Ios.secondary(context)),
            ),
          ),
          if (tx.fromSms) ...[
            const SizedBox(width: 5),
            Icon(
              CupertinoIcons.chat_bubble_text_fill,
              size: 12,
              color: Ios.secondary(context),
            ),
          ],
        ],
      ),
      trailing: Text(
        '${isExp ? '-' : '+'}${Fmt.money(tx.amount)}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isExp ? Ios.label(context) : IosColors.green,
        ),
      ),
      onTap: () => Navigator.push(context, iosRoute(TransactionForm(tx: tx))),
    );
  }
}

/// لصق نص رسالة بنكية يدوياً (مفيد على iOS حيث لا يمكن قراءة الرسائل).
Future<void> showPasteSmsDialog(BuildContext context, WidgetRef ref) async {
  final text = await promptDialog(
    context,
    title: 'لصق رسالة البنك',
    message: 'انسخ رسالة البنك والصقها هنا',
    placeholder: 'نص الرسالة',
    maxLines: 6,
    ok: 'تسجيل',
  );
  if (text == null || text.trim().isEmpty) return;
  final tx = await SmsService.instance.recordFromText(text.trim());
  refreshFinance(ref);
  if (!context.mounted) return;
  if (tx == null) {
    infoDialog(
      context,
      'لم يتم التسجيل',
      'لم أتعرف على عملية مالية في الرسالة، أو أنها سُجلت مسبقاً.',
    );
  } else {
    toast(
      context,
      'تم تسجيل ${tx.kind == TxKind.expense ? 'مصروف' : 'إيراد'} ${Fmt.money(tx.amount)}',
    );
    Navigator.push(context, iosRoute(TransactionForm(tx: tx)));
  }
}
