import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../services/notification_service.dart';

class EventForm extends ConsumerStatefulWidget {
  final Event? event;
  final DateTime? initialStart;
  const EventForm({super.key, this.event, this.initialStart});

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _location = TextEditingController(text: widget.event?.location);
  late final _notes = TextEditingController(text: widget.event?.notes);
  late DateTime _start =
      widget.event?.startAt ?? widget.initialStart ?? DateTime.now();
  late DateTime _end =
      widget.event?.endAt ?? _start.add(const Duration(hours: 1));
  late bool _allDay = widget.event?.allDay ?? false;
  late int? _reminder = widget.event == null
      ? 30
      : widget.event!.reminderMinutes;
  late int _color = widget.event?.color ?? AppTheme.palette[1].toARGB32();

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'اكتب عنوان الموعد');
      return;
    }
    if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
    var e = Event(
      id: widget.event?.id,
      title: _title.text.trim(),
      location: _location.text.trim(),
      notes: _notes.text.trim(),
      startAt: _allDay
          ? Fmt.dayStart(_start).add(const Duration(hours: 9))
          : _start,
      endAt: _allDay
          ? Fmt.dayStart(_end).add(const Duration(hours: 23, minutes: 59))
          : _end,
      allDay: _allDay,
      reminderMinutes: _reminder,
      color: _color,
    );
    if (e.id == null) {
      final id = await eventRepo.insert(e);
      e = Event.fromMap(e.toMap()..['id'] = id);
    } else {
      await eventRepo.update(e);
    }
    await NotificationService.instance.scheduleEvent(e);
    ref.invalidate(eventsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.event != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل موعد' : 'موعد جديد'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDialog(context, 'حذف هذا الموعد؟')) {
                  await NotificationService.instance.cancelEvent(
                    widget.event!.id!,
                  );
                  await eventRepo.delete(widget.event!.id!);
                  ref.invalidate(eventsProvider);
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
            autofocus: !editing,
            decoration: const InputDecoration(
              labelText: 'عنوان الموعد',
              prefixIcon: Icon(Icons.event),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'المكان',
              prefixIcon: Icon(Icons.place),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('طوال اليوم'),
                  secondary: const Icon(Icons.wb_sunny_outlined),
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('البداية'),
                  subtitle: Text(
                    _allDay ? Fmt.date(_start) : Fmt.dateTime(_start),
                  ),
                  onTap: () async {
                    final d = await pickDateTime(
                      context,
                      _start,
                      withTime: !_allDay,
                    );
                    if (d != null) {
                      setState(() {
                        final dur = _end.difference(_start);
                        _start = d;
                        _end = d.add(
                          dur.isNegative ? const Duration(hours: 1) : dur,
                        );
                      });
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.stop),
                  title: const Text('النهاية'),
                  subtitle: Text(_allDay ? Fmt.date(_end) : Fmt.dateTime(_end)),
                  onTap: () async {
                    final d = await pickDateTime(
                      context,
                      _end,
                      withTime: !_allDay,
                    );
                    if (d != null) setState(() => _end = d);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('التذكير'),
                  trailing: DropdownButton<int?>(
                    value: _reminder,
                    underline: const SizedBox(),
                    items: [
                      for (final e in reminderOptions.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _reminder = v),
                  ),
                ),
              ],
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
          ColorPicker(
            selected: _color,
            onChanged: (v) => setState(() => _color = v),
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

class ColorPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final c in AppTheme.palette)
        GestureDetector(
          onTap: () => onChanged(c.toARGB32()),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: c,
            child: c.toARGB32() == selected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        ),
    ],
  );
}
