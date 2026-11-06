import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'task_form.dart';
import 'task_tile.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tasksProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المهام'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                final q = await showSearchDialog(context, _query);
                if (q != null) setState(() => _query = q);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'اليوم'),
              Tab(text: 'القادمة'),
              Tab(text: 'الكل'),
              Tab(text: 'المنجزة'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskForm()),
          ),
          child: const Icon(Icons.add),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
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
            final now = DateTime.now();
            final endToday = Fmt.dayStart(now).add(const Duration(days: 1));
            final today = list
                .where(
                  (t) =>
                      !t.done && t.dueAt != null && t.dueAt!.isBefore(endToday),
                )
                .toList();
            final upcoming = list
                .where(
                  (t) =>
                      !t.done &&
                      (t.dueAt == null || !t.dueAt!.isBefore(endToday)),
                )
                .toList();
            final open = list.where((t) => !t.done).toList();
            final done = list.where((t) => t.done).toList()
              ..sort(
                (a, b) => (b.doneAt ?? b.createdAt).compareTo(
                  a.doneAt ?? a.createdAt,
                ),
              );

            final cats = {
              ...defaultTaskCategories,
              ...all.map((t) => t.category),
            };
            return Column(
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: const Text('الكل'),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                      ),
                      for (final c in cats)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(
                              () => _category = _category == c ? null : c,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InputChip(
                      label: Text('بحث: $_query'),
                      onDeleted: () => setState(() => _query = ''),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _list(today, subs, 'لا توجد مهام لليوم 🎉'),
                      _list(upcoming, subs, 'لا توجد مهام قادمة'),
                      _list(open, subs, 'لا توجد مهام مفتوحة'),
                      _list(done, subs, 'لم تُنجز أي مهمة بعد'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(List<Task> tasks, Map<int, List<Task>> subs, String empty) {
    if (tasks.isEmpty) return EmptyState(icon: Icons.task_alt, message: empty);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final t = tasks[i];
        return Dismissible(
          key: ValueKey('task-${t.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Icon(Icons.delete),
          ),
          confirmDismiss: (_) =>
              confirmDialog(context, 'حذف المهمة "${t.title}"؟'),
          onDismissed: (_) => TaskActions.delete(ref, t),
          child: TaskTile(task: t, subtasks: subs[t.id] ?? const []),
        );
      },
    );
  }
}

Future<String?> showSearchDialog(BuildContext context, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('بحث'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'اكتب كلمة للبحث'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('بحث'),
        ),
      ],
    ),
  );
}
