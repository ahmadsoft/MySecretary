import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../tasks/task_form.dart';
import '../tasks/task_tile.dart';
import 'event_form.dart';

/// هل يقع الموعد في هذا اليوم (يدعم المواعيد الممتدة لعدة أيام)؟
bool eventOnDay(Event e, DateTime day) {
  final d = Fmt.dayStart(day);
  return !Fmt.dayStart(e.startAt).isAfter(d) &&
      !Fmt.dayStart(e.endAt).isBefore(d);
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider).value ?? const <Event>[];
    final tasks = (ref.watch(tasksProvider).value ?? const <Task>[])
        .where((t) => t.dueAt != null && t.parentId == null)
        .toList();
    final c = Theme.of(context).colorScheme;

    List<Object> itemsFor(DateTime day) => [
      ...events.where((e) => eventOnDay(e, day)),
      ...tasks.where((t) => Fmt.sameDay(t.dueAt!, day)),
    ];

    final dayEvents = events.where((e) => eventOnDay(e, _selected)).toList();
    final dayTasks = tasks
        .where((t) => Fmt.sameDay(t.dueAt!, _selected))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقويم'),
        actions: [
          IconButton(
            tooltip: 'اليوم',
            icon: const Icon(Icons.today),
            onPressed: () =>
                setState(() => _focused = _selected = DateTime.now()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _addMenu(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          TableCalendar<Object>(
            locale: 'ar',
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            calendarFormat: _format,
            availableCalendarFormats: const {
              CalendarFormat.month: 'شهر',
              CalendarFormat.twoWeeks: 'أسبوعان',
              CalendarFormat.week: 'أسبوع',
            },
            startingDayOfWeek: StartingDayOfWeek.saturday,
            eventLoader: itemsFor,
            onFormatChanged: (f) => setState(() => _format = f),
            onDaySelected: (s, f) => setState(() {
              _selected = s;
              _focused = f;
            }),
            onPageChanged: (f) => _focused = f,
            headerStyle: const HeaderStyle(titleCentered: true),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: c.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: c.onPrimaryContainer),
              selectedDecoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: c.tertiary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
            ),
          ),
          SectionTitle('${Fmt.weekday(_selected)}، ${Fmt.date(_selected)}'),
          if (dayEvents.isEmpty && dayTasks.isEmpty)
            const SizedBox(
              height: 160,
              child: EmptyState(
                icon: Icons.event_available,
                message: 'لا يوجد شيء في هذا اليوم',
              ),
            ),
          for (final e in dayEvents) EventTile(event: e),
          for (final t in dayTasks) TaskTile(task: t),
        ],
      ),
    );
  }

  void _addMenu(BuildContext context) {
    final at = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
      DateTime.now().hour + 1,
    );
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('موعد جديد'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventForm(initialStart: at),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('مهمة في هذا اليوم'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskForm(initialDue: at)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EventTile extends StatelessWidget {
  final Event event;
  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final e = event;
    final time = e.allDay
        ? 'طوال اليوم'
        : '${Fmt.time(e.startAt)} - ${Fmt.time(e.endAt)}';
    return Card(
      child: ListTile(
        leading: Container(
          width: 6,
          height: 40,
          decoration: BoxDecoration(
            color: Color(e.color),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        title: Text(
          e.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [time, if (e.location.isNotEmpty) e.location].join(' • '),
        ),
        trailing: e.reminderMinutes != null
            ? const Icon(Icons.notifications_active, size: 18)
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventForm(event: e)),
        ),
      ),
    );
  }
}
