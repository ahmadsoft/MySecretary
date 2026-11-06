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
  late int _color = widget.event?.color ?? IosColors.blue.toARGB32();

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
    final tint = Ios.tint(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل موعد' : 'موعد جديد'),
        actions: [NavTextButton(editing ? 'تم' : 'إضافة', onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          IosSection(
            children: [
              IosField(_title, 'العنوان', autofocus: !editing),
              IosField(_location, 'الموقع'),
            ],
          ),
          IosSection(
            children: [
              IosTile(
                title: 'طوال اليوم',
                trailing: IosSwitch(
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
              ),
              IosTile(
                title: 'يبدأ',
                trailing: _DateChip(
                  _allDay ? Fmt.date(_start) : Fmt.dateTime(_start),
                  tint,
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
              IosTile(
                title: 'ينتهي',
                trailing: _DateChip(
                  _allDay ? Fmt.date(_end) : Fmt.dateTime(_end),
                  tint,
                ),
                onTap: () async {
                  final d = await pickDateTime(
                    context,
                    _end,
                    withTime: !_allDay,
                  );
                  if (d != null) setState(() => _end = d);
                },
              ),
            ],
          ),
          IosSection(
            children: [
              IosTile(
                title: 'التنبيه',
                value: reminderOptions[_reminder],
                chevron: true,
                onTap: () async {
                  final keys = [for (final k in reminderOptions.keys) k ?? -1];
                  final v = await pickFromList<int>(
                    context,
                    items: keys,
                    initial: _reminder ?? -1,
                    label: (k) => reminderOptions[k == -1 ? null : k]!,
                  );
                  if (v != null) setState(() => _reminder = v == -1 ? null : v);
                },
              ),
            ],
          ),
          IosSection(
            header: 'اللون',
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: ColorPicker(
                  selected: _color,
                  onChanged: (v) => setState(() => _color = v),
                ),
              ),
            ],
          ),
          IosSection(children: [IosField(_notes, 'ملاحظات', maxLines: 5)]),
          if (editing)
            IosSection(
              children: [
                IosTile(
                  title: 'حذف الموعد',
                  titleColor: IosColors.red,
                  onTap: () async {
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
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String text;
  final Color tint;
  const _DateChip(this.text, this.tint);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Ios.fill(context),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 15, color: Ios.label(context)),
    ),
  );
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
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final c in AppTheme.palette)
        GestureDetector(
          onTap: () => onChanged(c.toARGB32()),
          child: Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: c.toARGB32() == selected ? c : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ),
        ),
    ],
  );
}
