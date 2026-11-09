import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';

import 'package:table_calendar/table_calendar.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
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
    final tint = Ios.tint(context);

    List<Object> itemsFor(DateTime day) => [
      ...events.where((e) => eventOnDay(e, day)),
      ...tasks.where((t) => Fmt.sameDay(t.dueAt!, day)),
    ];

    final dayEvents = events.where((e) => eventOnDay(e, _selected)).toList();
    final dayTasks = tasks
        .where((t) => Fmt.sameDay(t.dueAt!, _selected))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: largeTitleBar(
        context,
        'التقويم',
        actions: [
          NavTextButton(
            'اليوم',
            bold: false,
            onPressed: () =>
                setState(() => _focused = _selected = DateTime.now()),
          ),
          NavIcon(
            CupertinoIcons.add,
            tooltip: 'إضافة',
            onPressed: () => _addMenu(context),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: tabBarSpace(context)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: IosSegmented<CalendarFormat>(
              items: const {
                CalendarFormat.month: 'شهر',
                CalendarFormat.twoWeeks: 'أسبوعان',
                CalendarFormat.week: 'أسبوع',
              },
              value: _format,
              onChanged: (f) => setState(() => _format = f),
            ),
          ),
          IosSection(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TableCalendar<Object>(
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
                  onDaySelected: (s, f) => setState(() {
                    _selected = s;
                    _focused = f;
                  }),
                  onPageChanged: (f) => _focused = f,
                  headerStyle: HeaderStyle(
                    titleCentered: false,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Ios.label(context),
                    ),
                    leftChevronIcon: Icon(
                      CupertinoIcons.chevron_right,
                      color: tint,
                      size: 20,
                    ),
                    rightChevronIcon: Icon(
                      CupertinoIcons.chevron_left,
                      color: tint,
                      size: 20,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      fontSize: 12,
                      color: Ios.secondary(context),
                    ),
                    weekendStyle: TextStyle(
                      fontSize: 12,
                      color: Ios.secondary(context),
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: TextStyle(
                      fontSize: 17,
                      color: Ios.label(context),
                    ),
                    weekendTextStyle: TextStyle(
                      fontSize: 17,
                      color: Ios.label(context),
                    ),
                    todayDecoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      fontSize: 17,
                      color: IosColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: isSameDay(_selected, DateTime.now())
                          ? IosColors.red
                          : Ios.label(context),
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isSameDay(_selected, DateTime.now())
                          ? Colors.white
                          : Ios.cell(context),
                    ),
                    markerDecoration: BoxDecoration(
                      color: Ios.tertiary(context),
                      shape: BoxShape.circle,
                    ),
                    markerSize: 5,
                    markersMaxCount: 3,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
            child: Text(
              '${Fmt.weekday(_selected)}، ${Fmt.date(_selected)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Ios.label(context),
              ),
            ),
          ),
          if (dayEvents.isEmpty && dayTasks.isEmpty)
            const SizedBox(
              height: 140,
              child: EmptyState(
                icon: CupertinoIcons.calendar,
                message: 'لا يوجد شيء في هذا اليوم',
              ),
            ),
          if (dayEvents.isNotEmpty)
            IosSection(
              header: 'المواعيد',
              children: [for (final e in dayEvents) EventTile(event: e)],
            ),
          if (dayTasks.isNotEmpty)
            IosSection(
              header: 'المهام',
              dividerIndent: 52,
              children: [for (final t in dayTasks) TaskTile(task: t)],
            ),
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
    showActionSheet(context, [
      SheetAction(
        'موعد جديد',
        () => Navigator.push(context, iosRoute(EventForm(initialStart: at))),
        icon: CupertinoIcons.calendar_badge_plus,
      ),
      SheetAction(
        'مهمة في هذا اليوم',
        () => Navigator.push(context, iosRoute(TaskForm(initialDue: at))),
        icon: CupertinoIcons.checkmark_circle,
      ),
    ]);
  }
}

/// صف موعد بطابع تقويم iPhone.
class EventTile extends StatelessWidget {
  final Event event;
  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final e = event;
    final sec = Ios.secondary(context);
    return InkWell(
      onTap: () => Navigator.push(context, iosRoute(EventForm(event: e))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 58,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: e.allDay
                      ? [
                          Text(
                            'طوال اليوم',
                            style: TextStyle(fontSize: 12, color: sec),
                          ),
                        ]
                      : [
                          Text(
                            Fmt.time(e.startAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Ios.label(context),
                            ),
                          ),
                          Text(
                            Fmt.time(e.endAt),
                            style: TextStyle(fontSize: 13, color: sec),
                          ),
                        ],
                ),
              ),
              Container(
                width: 4,
                margin: const EdgeInsetsDirectional.only(end: 10),
                decoration: BoxDecoration(
                  color: Color(e.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Ios.label(context),
                      ),
                    ),
                    if (e.location.isNotEmpty)
                      Text(
                        e.location,
                        style: TextStyle(fontSize: 13, color: sec),
                      ),
                  ],
                ),
              ),
              if (e.reminderMinutes != null)
                Center(
                  child: Icon(CupertinoIcons.bell_fill, size: 15, color: sec),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
