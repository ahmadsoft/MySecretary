import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/glass.dart';
import '../data/providers.dart';
import '../services/sms_service.dart';
import 'alarm/alarm_controller.dart';
import 'calendar/calendar_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'expenses/expenses_screen.dart';
import 'more_screen.dart';
import 'tasks/tasks_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SmsService.instance.onRecorded = () {
      if (mounted) refreshFinance(ref);
    };
    SmsService.instance.start();
    // المنبه بملء الشاشة بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AlarmController.instance.start(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AlarmController.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AlarmController.instance.check();
      // التقاط الرسائل التي وصلت أثناء إغلاق التطبيق
      SmsService.instance.syncInbox().then((_) {
        if (mounted) refreshFinance(ref);
      });
    }
  }

  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onNavigate: goTo),
      const TasksScreen(),
      const CalendarScreen(),
      const ExpensesScreen(),
      const MoreScreen(),
    ];
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: GlassScope(
          child: IndexedStack(index: _index, children: pages),
        ),
        bottomNavigationBar: GlassTabBar(
          currentIndex: _index,
          onTap: goTo,
          items: const [
            GlassTabItem(
              CupertinoIcons.house,
              CupertinoIcons.house_fill,
              'اليوم',
            ),
            GlassTabItem(
              CupertinoIcons.checkmark_circle,
              CupertinoIcons.checkmark_alt_circle_fill,
              'المهام',
            ),
            GlassTabItem(
              CupertinoIcons.calendar,
              CupertinoIcons.calendar_today,
              'التقويم',
            ),
            GlassTabItem(
              CupertinoIcons.creditcard,
              CupertinoIcons.creditcard_fill,
              'المصاريف',
            ),
            GlassTabItem(
              CupertinoIcons.square_grid_2x2,
              CupertinoIcons.square_grid_2x2_fill,
              'المزيد',
            ),
          ],
        ),
      ),
    );
  }
}
