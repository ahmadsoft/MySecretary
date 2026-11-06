import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'task_form.dart';
import 'task_tile.dart';

enum _View { today, upcoming, all, done }

const _viewLabels = {
  _View.today: 'اليوم',
  _View.upcoming: 'القادمة',
  _View.all: 'الكل',
  _View.done: 'المنجزة',
};

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String? _category;
  String _query = '';
  _View _view = _View.today;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tasksProvider);
    return Scaffold(
      appBar: largeTitleBar(
        context,
        'المهام',
        actions: [
          NavIcon(
            CupertinoIcons.search,
            tooltip: 'بحث',
            onPressed: () async {
              final q = await showSearchDialog(context, _query);
              if (q != null) setState(() => _query = q);
            },
          ),
          NavIcon(
            CupertinoIcons.add,
            tooltip: 'مهمة جديدة',
            onPressed: () =>
                Navigator.push(context, iosRoute(const TaskForm())),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (all) {
          final subs = <int, List<Task>>{};
          for (final t in all.where((t) => t.parentId != null)) {
            subs.putIfAbsent(t.parentId!, () => []).add(t);
          }
          var tasks = all.where((t) => t.parentId == null);
          if (_category != null) {
            tasks = tasks.where((t) => t.category == _category);
          }
          if (_query.isNotEmpty) {
            tasks = tasks.where(
              (t) => t.title.contains(_query) || t.notes.contains(_query),
            );
          }
          final list = tasks.toList();
          final endToday = Fmt.dayStart(DateTime.now())
              .add(const Duration(days: 1));
          final shown = switch (_view) {
            _View.today =>
              list
                  .where(
                    (t) =>
                        !t.done &&
                        t.dueAt != null &&
                        t.dueAt!.isBefore(endToday),
                  )
                  .toList(),
            _View.upcoming =>
              list
                  .where(
                    (t) =>
                        !t.done &&
                        (t.dueAt == null || !t.dueAt!.isBefore(endToday)),
                  )
                  .toList(),
            _View.all => list.where((t) => !t.done).toList(),
            _View.done =>
              list.where((t) => t.done).toList()..sort(
                (a, b) => (b.doneAt ?? b.createdAt).compareTo(
                  a.doneAt ?? a.createdAt,
                ),
              ),
          };
          final cats = <String?>[
            null,
            ...{...defaultTaskCategories, ...all.map((t) => t.category)},
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: IosSegmented<_View>(
                  items: _viewLabels,
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                ),
              ),
              FilterPills<String?>(
                values: cats,
                selected: _category,
                label: (c) => c ?? 'كل التصنيفات',
                onSelected: (c) => setState(() => _category = c),
              ),
              if (_query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'نتائج البحث: "$_query"',
                          style: TextStyle(color: Ios.secondary(context)),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text('مسح'),
                        onPressed: () => setState(() => _query = ''),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                SizedBox(
                  height: 300,
                  child: EmptyState(
                    icon: CupertinoIcons.checkmark_seal,
                    message: switch (_view) {
                      _View.today => 'لا توجد مهام لليوم 🎉',
                      _View.upcoming => 'لا توجد مهام قادمة',
                      _View.all => 'لا توجد مهام مفتوحة',
                      _View.done => 'لم تُنجز أي مهمة بعد',
                    },
                  ),
                )
              else
                IosSection(
                  dividerIndent: 52,
                  children: [
                    for (final t in shown)
                      Dismissible(
                        key: ValueKey('task-${t.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: IosColors.red,
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (_) =>
                            confirmDialog(context, 'حذف المهمة "${t.title}"؟'),
                        onDismissed: (_) => TaskActions.delete(ref, t),
                        child: TaskTile(
                          task: t,
                          subtasks: subs[t.id] ?? const [],
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<String?> showSearchDialog(BuildContext context, String initial) =>
    promptDialog(
      context,
      title: 'بحث',
      placeholder: 'اكتب كلمة للبحث',
      initial: initial,
      ok: 'بحث',
    );
