import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
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
      appBar: AppBar(
        title: const Text('المصاريف'),
        actions: [
          IconButton(
            tooltip: 'لصق رسالة بنك',
            icon: const Icon(Icons.content_paste),
            onPressed: () => showPasteSmsDialog(context, ref),
          ),
          if (SmsService.supported)
            IconButton(
              tooltip: 'قراءة الرسائل الآن',
              icon: const Icon(Icons.sync),
              onPressed: () async {
                if (!await SmsService.instance.isEnabled()) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmsSettingsScreen(),
                      ),
                    );
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
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionForm()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _MonthBar(month: month),
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (txs) => RefreshIndicator(
                onRefresh: () async {
                  await SmsService.instance.syncInbox();
                  refreshFinance(ref);
                },
                child: _body(context, txs, cats, catById),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<Tx> txs,
    List<Category> cats,
    Map<int?, Category> catById,
  ) {
    final exp = txs.where((t) => t.kind == TxKind.expense);
    final inc = txs.where((t) => t.kind == TxKind.income);
    final totalExp = exp.fold(0.0, (s, t) => s + t.amount);
    final totalInc = inc.fold(0.0, (s, t) => s + t.amount);
    final byCat = <int?, double>{};
    for (final t in exp) {
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final budgets = cats.where(
      (c) => c.kind == TxKind.expense && (c.monthlyBudget ?? 0) > 0,
    );

    // تجميع العمليات حسب اليوم
    final groups = <DateTime, List<Tx>>{};
    for (final t in txs) {
      groups.putIfAbsent(Fmt.dayStart(t.date), () => []).add(t);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        _SummaryCard(expense: totalExp, income: totalInc),
        if (sorted.isNotEmpty) ...[
          const SectionTitle('توزيع المصروفات'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: [
                          for (final e in sorted)
                            PieChartSectionData(
                              value: e.value,
                              color: Color(catById[e.key]?.color ?? 0xFF95A5A6),
                              radius: 30,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in sorted.take(6))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 5,
                                  backgroundColor: Color(
                                    catById[e.key]?.color ?? 0xFF95A5A6,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    catById[e.key]?.name ?? 'بدون تصنيف',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(e.value / totalExp * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
          ),
        ],
        if (budgets.isNotEmpty) ...[
          const SectionTitle('الميزانية الشهرية'),
          for (final c in budgets)
            _BudgetRow(category: c, spent: byCat[c.id] ?? 0),
        ],
        const SectionTitle('العمليات'),
        if (txs.isEmpty)
          const SizedBox(
            height: 200,
            child: EmptyState(
              icon: Icons.receipt_long,
              message: 'لا توجد عمليات في هذا الشهر',
            ),
          ),
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 2),
            child: Text(
              '${Fmt.weekday(g.key)} ${Fmt.date(g.key)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13,
              ),
            ),
          ),
          for (final t in g.value)
            TxTile(tx: t, category: catById[t.categoryId]),
        ],
      ],
    );
  }
}

class _MonthBar extends ConsumerWidget {
  final DateTime month;
  const _MonthBar({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(selectedMonthProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => n.shift(-1),
          ),
          Expanded(
            child: Text(
              Fmt.month(month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => n.shift(1),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double expense, income;
  const _SummaryCard({required this.expense, required this.income});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget col(String label, double v, Color color) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              child: Text(
                Fmt.money(v),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Card(
      color: c.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          children: [
            col('المصروفات', expense, const Color(0xFFC0392B)),
            col('الإيرادات', income, const Color(0xFF1E8449)),
            col('الصافي', income - expense, c.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
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
        ? Colors.red
        : (ratio > 0.8 ? Colors.orange : Color(category.color));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconAt(category.icon),
                  size: 18,
                  color: Color(category.color),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(category.name)),
                Text(
                  '${Fmt.money(spent)} / ${Fmt.money(b)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (over)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'تجاوزت الميزانية بـ ${Fmt.money(spent - b)}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TxTile extends StatelessWidget {
  final Tx tx;
  final Category? category;
  const TxTile({super.key, required this.tx, this.category});

  @override
  Widget build(BuildContext context) {
    final isExp = tx.kind == TxKind.expense;
    final color = Color(category?.color ?? 0xFF95A5A6);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(iconAt(category?.icon ?? -1), color: color),
        ),
        title: Text(
          tx.merchant.isNotEmpty
              ? tx.merchant
              : (category?.name ?? 'بدون تصنيف'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                '${category?.name ?? 'بدون تصنيف'} • ${paymentLabels[tx.method]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tx.fromSms) ...[
              const SizedBox(width: 6),
              const Icon(Icons.sms, size: 14),
            ],
          ],
        ),
        trailing: Text(
          '${isExp ? '-' : '+'}${Fmt.money(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExp ? const Color(0xFFC0392B) : const Color(0xFF1E8449),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TransactionForm(tx: tx)),
        ),
      ),
    );
  }
}

/// لصق نص رسالة بنكية يدوياً (مفيد على iOS حيث لا يمكن قراءة الرسائل).
Future<void> showPasteSmsDialog(BuildContext context, WidgetRef ref) async {
  final c = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('لصق رسالة البنك'),
      content: TextField(
        controller: c,
        maxLines: 6,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'انسخ رسالة البنك والصقها هنا',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('تسجيل'),
        ),
      ],
    ),
  );
  if (text == null || text.trim().isEmpty) return;
  final tx = await SmsService.instance.recordFromText(text.trim());
  refreshFinance(ref);
  if (!context.mounted) return;
  if (tx == null) {
    toast(context, 'لم أتعرف على عملية مالية في الرسالة (أو سُجلت مسبقاً)');
  } else {
    toast(
      context,
      'تم تسجيل ${tx.kind == TxKind.expense ? 'مصروف' : 'إيراد'} ${Fmt.money(tx.amount)}',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransactionForm(tx: tx)),
    );
  }
}
