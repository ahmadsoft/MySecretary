import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// خيارات التذكير بالنسبة لموعد الاستحقاق.
const _reminderOffsets = <int?, String>{
  null: 'بدون تذكير',
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
    final t = Task(
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
    );
    await TaskActions.save(ref, t);
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
    final c = Theme.of(context).colorScheme;
    final cats = {...defaultTaskCategories, _category}.toList();
    final subtasks = _editing
        ? (ref.watch(tasksProvider).value ?? const <Task>[])
              .where((t) => t.parentId == widget.task!.id)
              .toList()
        : const <Task>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'تعديل مهمة' : 'مهمة جديدة'),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDialog(context, 'حذف هذه المهمة؟')) {
                  await TaskActions.delete(ref, widget.task!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: !_editing,
            decoration: const InputDecoration(
              labelText: 'عنوان المهمة',
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 16),
          const Text('الأولوية', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (var i = 0; i < 3; i++)
                ButtonSegment(
                  value: i,
                  label: FittedBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 18,
                          color: AppTheme.priorityColors[i],
                        ),
                        const SizedBox(width: 4),
                        Text(priorityLabels[i]),
                      ],
                    ),
                  ),
                ),
            ],
            showSelectedIcon: false,
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'التصنيف',
              prefixIcon: Icon(Icons.label),
            ),
            items: [
              for (final x in cats) DropdownMenuItem(value: x, child: Text(x)),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('موعد الاستحقاق'),
                  subtitle: Text(
                    _due == null ? 'بدون موعد' : Fmt.dateTime(_due!),
                  ),
                  trailing: _due == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _due = null),
                        ),
                  onTap: () async {
                    final d = await pickDateTime(
                      context,
                      _due ?? DateTime.now().add(const Duration(hours: 1)),
                    );
                    if (d != null) {
                      setState(() {
                        _due = d;
                        _reminder ??= 0;
                      });
                    }
                  },
                ),
                if (_due != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('التذكير'),
                    trailing: DropdownButton<int?>(
                      value: _reminder,
                      underline: const SizedBox(),
                      items: [
                        for (final e in _reminderOffsets.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _reminder = v),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.repeat),
                    title: const Text('التكرار'),
                    trailing: DropdownButton<Repeat>(
                      value: _repeat,
                      underline: const SizedBox(),
                      items: [
                        for (final e in repeatLabels.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _repeat = v!),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_editing && widget.task!.parentId == null) ...[
            const SizedBox(height: 16),
            const Text(
              'المهام الفرعية',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final s in subtasks)
              CheckboxListTile(
                value: s.done,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.title,
                  style: TextStyle(
                    decoration: s.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                secondary: IconButton(
                  icon: Icon(Icons.close, color: c.outline),
                  onPressed: () => TaskActions.delete(ref, s),
                ),
                onChanged: (_) => TaskActions.toggle(ref, s),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sub,
                    decoration: const InputDecoration(
                      hintText: 'أضف مهمة فرعية',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addSubtask,
                ),
              ],
            ),
          ],
          if (!_editing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'يمكنك إضافة مهام فرعية بعد حفظ المهمة.',
                style: TextStyle(color: c.outline, fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('حفظ'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}
