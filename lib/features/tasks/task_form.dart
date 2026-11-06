import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// خيارات التذكير بالنسبة لموعد الاستحقاق.
const _reminderOffsets = <int?, String>{
  null: 'بدون',
  0: 'وقت الاستحقاق',
  15: 'قبل 15 دقيقة',
  60: 'قبل ساعة',
  1440: 'قبل يوم',
};

class TaskForm extends ConsumerStatefulWidget {
  final Task? task;
  final DateTime? initialDue;
  const TaskForm({super.key, this.task, this.initialDue});

  @override
  ConsumerState<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<TaskForm> {
  late final _title = TextEditingController(text: widget.task?.title);
  late final _notes = TextEditingController(text: widget.task?.notes);
  final _sub = TextEditingController();
  late int _priority = widget.task?.priority ?? 1;
  late String _category = widget.task?.category ?? 'شخصي';
  late DateTime? _due = widget.task?.dueAt ?? widget.initialDue;
  late int? _reminder = _initialOffset();
  late Repeat _repeat = widget.task?.repeat ?? Repeat.none;

  bool get _editing => widget.task != null;

  int? _initialOffset() {
    final t = widget.task;
    if (t == null) return widget.initialDue != null ? 0 : null;
    if (t.reminderAt == null || t.dueAt == null) return null;
    final m = t.dueAt!.difference(t.reminderAt!).inMinutes;
    return _reminderOffsets.containsKey(m) ? m : 0;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, 'اكتب عنوان المهمة');
      return;
    }
    final reminderAt = (_due != null && _reminder != null)
        ? _due!.subtract(Duration(minutes: _reminder!))
        : null;
    final base = widget.task;
    await TaskActions.save(
      ref,
      Task(
        id: base?.id,
        title: title,
        notes: _notes.text.trim(),
        priority: _priority,
        category: _category,
        dueAt: _due,
        reminderAt: reminderAt,
        repeat: _due == null ? Repeat.none : _repeat,
        done: base?.done ?? false,
        doneAt: base?.doneAt,
        parentId: base?.parentId,
        createdAt: base?.createdAt,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addSubtask() async {
    final s = _sub.text.trim();
    if (s.isEmpty || widget.task?.id == null) return;
    await TaskActions.save(
      ref,
      Task(title: s, parentId: widget.task!.id, category: _category),
    );
    _sub.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cats = {...defaultTaskCategories, _category}.toList();
    final subtasks = _editing
        ? (ref.watch(tasksProvider).value ?? const <Task>[])
              .where((t) => t.parentId == widget.task!.id)
              .toList()
        : const <Task>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'التفاصيل' : 'مهمة جديدة'),
        actions: [NavTextButton(_editing ? 'تم' : 'إضافة', onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          IosSection(
            children: [
              IosField(_title, 'العنوان', autofocus: !_editing),
              IosField(_notes, 'ملاحظات', maxLines: 5),
            ],
          ),
          IosSection(
            header: 'الأولوية',
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: IosSegmented<int>(
                  items: {for (var i = 0; i < 3; i++) i: priorityLabels[i]},
                  value: _priority,
                  onChanged: (v) => setState(() => _priority = v),
                ),
              ),
            ],
          ),
          IosSection(
            dividerIndent: 60,
            children: [
              IosTile(
                leading: const IconBadge(
                  CupertinoIcons.calendar,
                  IosColors.red,
                ),
                title: 'التاريخ والوقت',
                subtitleWidget: _due == null
                    ? null
                    : Text(
                        Fmt.dateTime(_due!),
                        style: TextStyle(
                          fontSize: 14,
                          color: Ios.tint(context),
                        ),
                      ),
                trailing: IosSwitch(
                  value: _due != null,
                  onChanged: (v) async {
                    if (!v) {
                      setState(() => _due = null);
                      return;
                    }
                    final d = await pickDateTime(
                      context,
                      DateTime.now().add(const Duration(hours: 1)),
                    );
                    if (d != null) {
                      setState(() {
                        _due = d;
                        _reminder ??= 0;
                      });
                    }
                  },
                ),
                onTap: _due == null
                    ? null
                    : () async {
                        final d = await pickDateTime(context, _due!);
                        if (d != null) setState(() => _due = d);
                      },
              ),
              if (_due != null) ...[
                IosTile(
                  leading: const IconBadge(
                    CupertinoIcons.bell_fill,
                    IosColors.orange,
                  ),
                  title: 'التذكير',
                  value: _reminderOffsets[_reminder],
                  chevron: true,
                  onTap: () async {
                    // -1 = بدون تذكير (null لا يصلح لأنه يعني الإلغاء)
                    final keys = [
                      for (final k in _reminderOffsets.keys) k ?? -1,
                    ];
                    final v = await pickFromList<int>(
                      context,
                      items: keys,
                      initial: _reminder ?? -1,
                      label: (k) => _reminderOffsets[k == -1 ? null : k]!,
                    );
                    if (v != null) {
                      setState(() => _reminder = v == -1 ? null : v);
                    }
                  },
                ),
                IosTile(
                  leading: const IconBadge(
                    CupertinoIcons.repeat,
                    IosColors.gray,
                  ),
                  title: 'التكرار',
                  value: repeatLabels[_repeat],
                  chevron: true,
                  onTap: () async {
                    final v = await pickFromList<Repeat>(
                      context,
                      items: Repeat.values,
                      initial: _repeat,
                      label: (r) => repeatLabels[r]!,
                    );
                    if (v != null) setState(() => _repeat = v);
                  },
                ),
              ],
            ],
          ),
          IosSection(
            dividerIndent: 60,
            children: [
              IosTile(
                leading: const IconBadge(
                  CupertinoIcons.tag_fill,
                  IosColors.purple,
                ),
                title: 'التصنيف',
                value: _category,
                chevron: true,
                onTap: () async {
                  final v = await pickFromList<String>(
                    context,
                    items: cats,
                    initial: _category,
                    label: (c) => c,
                  );
                  if (v != null) setState(() => _category = v);
                },
              ),
            ],
          ),
          if (_editing && widget.task!.parentId == null)
            IosSection(
              header: 'المهام الفرعية',
              dividerIndent: 52,
              children: [
                for (final s in subtasks)
                  Row(
                    children: [
                      const SizedBox(width: 14),
                      IosCheck(
                        done: s.done,
                        color: s.done ? Ios.tint(context) : IosColors.gray,
                        onTap: () => TaskActions.toggle(ref, s),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.title,
                          style: TextStyle(
                            fontSize: 17,
                            color: s.done
                                ? Ios.secondary(context)
                                : Ios.label(context),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: Ios.tertiary(context),
                        ),
                        onPressed: () => TaskActions.delete(ref, s),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      CupertinoIcons.plus_circle_fill,
                      color: Ios.tint(context),
                      size: 26,
                    ),
                    Expanded(
                      child: IosField(
                        _sub,
                        'مهمة فرعية جديدة',
                        onSubmitted: (_) => _addSubtask(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (!_editing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'يمكنك إضافة مهام فرعية بعد حفظ المهمة.',
                style: TextStyle(color: Ios.secondary(context), fontSize: 13),
              ),
            ),
          if (_editing)
            IosSection(
              children: [
                IosTile(
                  title: 'حذف المهمة',
                  titleColor: IosColors.red,
                  onTap: () async {
                    if (await confirmDialog(context, 'حذف هذه المهمة؟')) {
                      await TaskActions.delete(ref, widget.task!);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
