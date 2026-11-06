import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/providers.dart';
import '../services/sms_service.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
    final c = Theme.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: goTo,
        activeColor: c.colorScheme.primary,
        inactiveColor: IosColors.gray,
        backgroundColor: c.brightness == Brightness.dark
            ? const Color(0xF01C1C1E)
            : const Color(0xF0F9F9F9),
        height: 54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'اليوم',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.checkmark_circle),
            activeIcon: Icon(CupertinoIcons.checkmark_alt_circle_fill),
            label: 'المهام',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            activeIcon: Icon(CupertinoIcons.calendar_today),
            label: 'التقويم',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.creditcard),
            activeIcon: Icon(CupertinoIcons.creditcard_fill),
            label: 'المصاريف',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}
