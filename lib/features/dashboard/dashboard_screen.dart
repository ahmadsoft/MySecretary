import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
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
    final tasks = (ref.watch(tasksProvider).value ?? const <Task>[])
        .where((t) => t.parentId == null)
        .toList();
    final events = ref.watch(eventsProvider).value ?? const <Event>[];
    final txs =
        ref.watch(monthTxProvider(DateTime(now.year, now.month))).value ??
        const <Tx>[];

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

    void push(Widget w) => Navigator.push(context, iosRoute(w));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(tasksProvider);
            ref.invalidate(eventsProvider);
            refreshFinance(ref);
          },
          child: ListView(
            padding: EdgeInsets.only(bottom: tabBarSpace(context)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.weekday(now)}، ${Fmt.date(now)}'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Ios.secondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.greeting(now),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: Ios.label(context),
                      ),
                    ),
                  ],
                ),
              ),
              // بطاقات زجاجية
              CardGrid(
                children: [
                  _SmartCard(
                    icon: CupertinoIcons.checkmark_alt_circle_fill,
                    color: IosColors.blue,
                    title: 'مهام اليوم',
                    subtitle: todayTotal == 0
                        ? 'لا توجد مهام'
                        : 'أنجزت $todayDone من $todayTotal',
                    value: todayTotal == 0 ? '0' : '$todayDone/$todayTotal',
                    badge: todayTotal == 0
                        ? null
                        : '${(todayDone / todayTotal * 100).round()}%',
                    progress: todayTotal == 0 ? 0 : todayDone / todayTotal,
                    onTap: () => onNavigate(1),
                  ),
                  _SmartCard(
                    icon: CupertinoIcons.exclamationmark_circle_fill,
                    color: overdue.isEmpty ? IosColors.green : IosColors.red,
                    title: 'متأخرة',
                    subtitle: overdue.isEmpty
                        ? 'كل شيء في وقته'
                        : 'تحتاج متابعة',
                    value: '${overdue.length}',
                    onTap: () => onNavigate(1),
                  ),
                  _SmartCard(
                    icon: CupertinoIcons.calendar,
                    color: IosColors.red,
                    title: 'مواعيد اليوم',
                    subtitle: todayEvents.isEmpty
                        ? 'يومك فارغ'
                        : 'الأول ${todayEvents.first.allDay ? 'طوال اليوم' : Fmt.time(todayEvents.first.startAt)}',
                    value: '${todayEvents.length}',
                    onTap: () => onNavigate(2),
                  ),
                  _SmartCard(
                    icon: CupertinoIcons.creditcard_fill,
                    color: IosColors.orange,
                    title: 'مصروف اليوم',
                    subtitle: 'الشهر ${Fmt.money(monthExpense)}',
                    value: Fmt.money(todayExpense),
                    onTap: () => onNavigate(3),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              IosSection(
                header: 'إضافة سريعة',
                dividerIndent: 60,
                children: [
                  Row(
                    children: [
                      _quick(
                        context,
                        CupertinoIcons.checkmark_circle_fill,
                        IosColors.blue,
                        'مهمة',
                        () => push(const TaskForm()),
                      ),
                      _quick(
                        context,
                        CupertinoIcons.calendar_badge_plus,
                        IosColors.red,
                        'موعد',
                        () => push(const EventForm()),
                      ),
                      _quick(
                        context,
                        CupertinoIcons.doc_text_fill,
                        IosColors.yellow,
                        'ملاحظة',
                        () => push(const NoteEditor()),
                      ),
                      _quick(
                        context,
                        CupertinoIcons.creditcard_fill,
                        IosColors.green,
                        'مصروف',
                        () => push(const TransactionForm()),
                      ),
                    ],
                  ),
                ],
              ),
              if (todayEvents.isNotEmpty)
                IosSection(
                  header: 'مواعيد اليوم',
                  headerTrailing: _link(
                    context,
                    'التقويم',
                    () => onNavigate(2),
                  ),
                  children: [for (final e in todayEvents) EventTile(event: e)],
                ),
              IosSection(
                header: 'مهام اليوم',
                headerTrailing: _link(context, 'الكل', () => onNavigate(1)),
                dividerIndent: 52,
                children: overdue.isEmpty && todayOpen.isEmpty
                    ? [const IosTile(title: 'لا توجد مهام متبقية لليوم 🎉')]
                    : [
                        for (final t in overdue) TaskTile(task: t),
                        for (final t in todayOpen) TaskTile(task: t),
                      ],
              ),
              IosSection(
                header: 'المصاريف',
                headerTrailing: _link(context, 'التفاصيل', () => onNavigate(3)),
                children: [
                  IosTile(title: 'اليوم', value: Fmt.money(todayExpense)),
                  IosTile(title: 'هذا الشهر', value: Fmt.money(monthExpense)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(BuildContext context, String t, VoidCallback onTap) =>
      CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        onPressed: onTap,
        child: Text(t, style: const TextStyle(fontSize: 15)),
      );

  Widget _quick(
    BuildContext context,
    IconData i,
    Color color,
    String label,
    VoidCallback onTap,
  ) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            IconBadge(i, color, size: 44),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Ios.label(context)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// بطاقة مثل "اليوم/المجدولة" في تطبيق التذكيرات.
class _SmartCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? subtitle;
  final String? badge;
  final double? progress;
  final VoidCallback onTap;
  const _SmartCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.progress,
  });

  @override
  Widget build(BuildContext context) => StatCard(
    icon: icon,
    color: color,
    title: title,
    subtitle: subtitle,
    value: value,
    badge: badge,
    progress: progress,
    onTap: onTap,
  );
}
