import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../calendar/calendar_screen.dart' show EventTile, eventOnDay;
import '../calendar/event_form.dart';
import '../expenses/transaction_form.dart';
import '../notes/note_editor.dart';
import '../tasks/task_form.dart';
import '../tasks/task_tile.dart';

class DashboardScreen extends ConsumerWidget {
  final ValueChanged<int> onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final c = Theme.of(context).colorScheme;
    final tasks = (ref.watch(tasksProvider).value ?? const <Task>[])
        .where((t) => t.parentId == null)
        .toList();
    final events = ref.watch(eventsProvider).value ?? const <Event>[];
    final month = DateTime(now.year, now.month);
    final txs = ref.watch(monthTxProvider(month)).value ?? const <Tx>[];

    final todayAll = tasks.where(
      (t) => t.dueAt != null && Fmt.sameDay(t.dueAt!, now),
    );
    final todayDone = todayAll.where((t) => t.done).length;
    final todayTotal = todayAll.length;
    final overdue = tasks
        .where((t) => t.isOverdue && !Fmt.sameDay(t.dueAt!, now))
        .toList();
    final todayOpen = tasks
        .where((t) => !t.done && t.dueAt != null && Fmt.sameDay(t.dueAt!, now))
        .toList();
    final todayEvents = events.where((e) => eventOnDay(e, now)).toList();
    final monthExpense = txs
        .where((t) => t.kind == TxKind.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final todayExpense = txs
        .where((t) => t.kind == TxKind.expense && Fmt.sameDay(t.date, now))
        .fold(0.0, (s, t) => s + t.amount);

    void push(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tasksProvider);
            ref.invalidate(eventsProvider);
            refreshFinance(ref);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.greeting(now)} 👋',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Fmt.weekday(now)}، ${Fmt.date(now)}',
                      style: TextStyle(color: c.outline),
                    ),
                  ],
                ),
              ),
              // بطاقة الإنجاز
              Card(
                color: c.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                value: todayTotal == 0
                                    ? 0
                                    : todayDone / todayTotal,
                                strokeWidth: 7,
                                backgroundColor: c.onPrimaryContainer
                                    .withValues(alpha: 0.15),
                                color: c.primary,
                              ),
                            ),
                            Text(
                              todayTotal == 0
                                  ? '—'
                                  : '${(todayDone / todayTotal * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: c.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إنجاز اليوم',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: c.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              todayTotal == 0
                                  ? 'لا توجد مهام مجدولة لليوم'
                                  : 'أنجزت $todayDone من $todayTotal مهام',
                              style: TextStyle(color: c.onPrimaryContainer),
                            ),
                            if (overdue.isNotEmpty)
                              Text(
                                '${overdue.length} مهام متأخرة',
                                style: TextStyle(
                                  color: c.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // اختصارات سريعة
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _quick(
                      context,
                      Icons.add_task,
                      'مهمة',
                      () => push(const TaskForm()),
                    ),
                    _quick(
                      context,
                      Icons.event,
                      'موعد',
                      () => push(const EventForm()),
                    ),
                    _quick(
                      context,
                      Icons.note_add,
                      'ملاحظة',
                      () => push(const NoteEditor()),
                    ),
                    _quick(
                      context,
                      Icons.add_card,
                      'مصروف',
                      () => push(const TransactionForm()),
                    ),
                  ],
                ),
              ),
              SectionTitle(
                'مواعيد اليوم',
                trailing: TextButton(
                  onPressed: () => onNavigate(2),
                  child: const Text('التقويم'),
                ),
              ),
              if (todayEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Text(
                    'لا توجد مواعيد اليوم',
                    style: TextStyle(color: c.outline),
                  ),
                ),
              for (final e in todayEvents) EventTile(event: e),
              SectionTitle(
                'مهام اليوم',
                trailing: TextButton(
                  onPressed: () => onNavigate(1),
                  child: const Text('كل المهام'),
                ),
              ),
              if (todayOpen.isEmpty && overdue.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Text(
                    'لا توجد مهام متبقية لليوم 🎉',
                    style: TextStyle(color: c.outline),
                  ),
                ),
              for (final t in overdue) TaskTile(task: t),
              for (final t in todayOpen) TaskTile(task: t),
              SectionTitle(
                'المصاريف',
                trailing: TextButton(
                  onPressed: () => onNavigate(3),
                  child: const Text('التفاصيل'),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: _stat(context, 'اليوم', todayExpense)),
                      Container(width: 1, height: 36, color: c.outlineVariant),
                      Expanded(
                        child: _stat(context, 'هذا الشهر', monthExpense),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quick(
    BuildContext context,
    IconData i,
    String label,
    VoidCallback onTap,
  ) {
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.secondaryContainer,
                child: Icon(i, color: c.onSecondaryContainer),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, double v) => Column(
    children: [
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
      const SizedBox(height: 4),
      FittedBox(
        child: Text(
          Fmt.money(v),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Color(0xFFC0392B),
          ),
        ),
      ),
    ],
  );
}
