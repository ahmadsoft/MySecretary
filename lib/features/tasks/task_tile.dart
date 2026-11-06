import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'task_form.dart';

/// صف مهمة بطابع تطبيق "التذكيرات" في iPhone (يوضع داخل IosSection).
class TaskTile extends ConsumerWidget {
  final Task task;
  final List<Task> subtasks;
  const TaskTile({super.key, required this.task, this.subtasks = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = task;
    final sec = Ios.secondary(context);
    final doneSubs = subtasks.where((s) => s.done).length;
    final parts = <InlineSpan>[];
    void add(String s, {Color? color, IconData? icon}) {
      if (parts.isNotEmpty) {
        parts.add(
          TextSpan(
            text: '  ·  ',
            style: TextStyle(color: sec),
          ),
        );
      }
      if (icon != null) {
        parts.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 3),
              child: Icon(icon, size: 13, color: color ?? sec),
            ),
          ),
        );
      }
      parts.add(
        TextSpan(
          text: s,
          style: TextStyle(color: color ?? sec),
        ),
      );
    }

    if (t.dueAt != null) {
      add(
        Fmt.sameDay(t.dueAt!, DateTime.now())
            ? 'اليوم ${Fmt.time(t.dueAt!)}'
            : Fmt.dateTime(t.dueAt!),
        color: t.isOverdue ? IosColors.red : null,
      );
    }
    if (t.repeat != Repeat.none) {
      add(repeatLabels[t.repeat]!, icon: CupertinoIcons.repeat);
    }
    if (subtasks.isNotEmpty) {
      add('$doneSubs/${subtasks.length}', icon: CupertinoIcons.list_bullet);
    }
    add(t.category);

    final checkColor = t.done
        ? Ios.tint(context)
        : AppTheme.priorityColors[t.priority];
    return InkWell(
      onTap: () => Navigator.push(context, iosRoute(TaskForm(task: t))),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IosCheck(
              done: t.done,
              color: checkColor,
              onTap: () => TaskActions.toggle(ref, t),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        if (t.priority == 2 && !t.done)
                          const TextSpan(
                            text: '!!! ',
                            style: TextStyle(
                              color: IosColors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        TextSpan(text: t.title),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      color: t.done ? sec : Ios.label(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: parts),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            if (t.reminderAt != null && !t.done)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(CupertinoIcons.bell_fill, size: 15, color: sec),
              ),
          ],
        ),
      ),
    );
  }
}
