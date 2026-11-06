import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'task_form.dart';

class TaskTile extends ConsumerWidget {
  final Task task;
  final List<Task> subtasks;
  const TaskTile({super.key, required this.task, this.subtasks = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final t = task;
    final doneSubs = subtasks.where((s) => s.done).length;
    final info = <Widget>[];
    if (t.dueAt != null) {
      info.add(
        _chip(
          Icons.schedule,
          Fmt.sameDay(t.dueAt!, DateTime.now())
              ? 'اليوم ${Fmt.time(t.dueAt!)}'
              : Fmt.dateTime(t.dueAt!),
          t.isOverdue ? c.error : c.outline,
        ),
      );
    }
    if (t.reminderAt != null && !t.done) {
      info.add(_chip(Icons.notifications_active, '', c.outline));
    }
    if (t.repeat != Repeat.none) {
      info.add(_chip(Icons.repeat, repeatLabels[t.repeat]!, c.outline));
    }
    if (subtasks.isNotEmpty) {
      info.add(
        _chip(Icons.checklist, '$doneSubs/${subtasks.length}', c.outline),
      );
    }
    info.add(_chip(Icons.label_outline, t.category, c.outline));

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 12),
        leading: Checkbox(
          value: t.done,
          shape: const CircleBorder(),
          activeColor: c.primary,
          side: BorderSide(
            color: AppTheme.priorityColors[t.priority],
            width: 2,
          ),
          onChanged: (_) => TaskActions.toggle(ref, t),
        ),
        title: Text(
          t.title,
          style: TextStyle(
            decoration: t.done ? TextDecoration.lineThrough : null,
            color: t.done ? c.outline : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 10, runSpacing: 2, children: info),
        ),
        trailing: t.priority == 2
            ? Icon(Icons.flag, color: AppTheme.priorityColors[2], size: 20)
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskForm(task: t)),
        ),
      ),
    );
  }

  Widget _chip(IconData i, String s, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 14, color: color),
      if (s.isNotEmpty) ...[
        const SizedBox(width: 3),
        Text(s, style: TextStyle(fontSize: 12, color: color)),
      ],
    ],
  );
}
