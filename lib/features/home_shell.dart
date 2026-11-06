import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'اليوم',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'المهام',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'التقويم',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'المصاريف',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}
