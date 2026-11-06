import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import 'estate_calc.dart';
import 'models.dart';
import 'repository.dart';

final taskRepo = TaskRepo();
final eventRepo = EventRepo();
final noteRepo = NoteRepo();
final financeRepo = FinanceRepo();
final estateRepo = EstateRepo();

// ───────────── المهام ─────────────
final tasksProvider = FutureProvider<List<Task>>((ref) => taskRepo.all());

class TaskActions {
  static Future<void> save(WidgetRef ref, Task t) async {
    final id = t.id ?? await taskRepo.insert(t);
    if (t.id != null) await taskRepo.update(t);
    await NotificationService.instance.scheduleTask(t.copyWith(id: id));
    ref.invalidate(tasksProvider);
  }

  /// إنجاز/إلغاء إنجاز مهمة. المهمة المتكررة تُنشئ نسختها التالية تلقائياً.
  static Future<void> toggle(WidgetRef ref, Task t) async {
    final done = !t.done;
    final updated = Task.fromMap(
      t.toMap()
        ..['done'] = done ? 1 : 0
        ..['done_at'] = done ? DateTime.now().millisecondsSinceEpoch : null,
    );
    await taskRepo.update(updated);
    await NotificationService.instance.scheduleTask(updated);
    if (done &&
        t.repeat != Repeat.none &&
        t.dueAt != null &&
        t.parentId == null) {
      final next = Task(
        title: t.title,
        notes: t.notes,
        priority: t.priority,
        category: t.category,
        repeat: t.repeat,
        dueAt: nextOccurrence(t.dueAt!, t.repeat),
        reminderAt: t.reminderAt == null
            ? null
            : nextOccurrence(t.reminderAt!, t.repeat),
      );
      final id = await taskRepo.insert(next);
      await NotificationService.instance.scheduleTask(next.copyWith(id: id));
    }
    ref.invalidate(tasksProvider);
  }

  static Future<void> delete(WidgetRef ref, Task t) async {
    await NotificationService.instance.cancelTask(t.id!);
    await taskRepo.delete(t.id!);
    ref.invalidate(tasksProvider);
  }
}

// ───────────── المواعيد والملاحظات ─────────────
final eventsProvider = FutureProvider<List<Event>>((ref) => eventRepo.all());
final notesProvider = FutureProvider<List<Note>>((ref) => noteRepo.all());

// ───────────── المصاريف ─────────────
final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => financeRepo.categories(),
);

/// الشهر المعروض حالياً في شاشة المصاريف.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  void shift(int months) => state = DateTime(state.year, state.month + months);
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);

final monthTxProvider = FutureProvider.family<List<Tx>, DateTime>(
  (ref, m) =>
      financeRepo.transactions(from: m, to: DateTime(m.year, m.month + 1)),
);

void refreshFinance(WidgetRef ref) {
  ref.invalidate(monthTxProvider);
  ref.invalidate(categoriesProvider);
}

// ───────────── حسابات الورثة ─────────────
final estatesProvider = FutureProvider<List<Estate>>(
  (ref) => estateRepo.estates(),
);

class EstateData {
  final Estate estate;
  final List<Heir> heirs;
  final List<IncomeSource> sources;
  final List<EstateEntry> entries;
  final EstateSummary summary;
  EstateData(this.estate, this.heirs, this.sources, this.entries)
    : summary = EstateSummary.compute(heirs, entries);

  String sourceName(int? id) =>
      sources.where((s) => s.id == id).map((s) => s.name).firstOrNull ??
      'غير محدد';
  String heirName(int? id) =>
      heirs.where((h) => h.id == id).map((h) => h.name).firstOrNull ??
      'غير محدد';
}

final estateDataProvider = FutureProvider.family<EstateData, int>((
  ref,
  id,
) async {
  final e = await estateRepo.estateById(id);
  return EstateData(
    e!,
    await estateRepo.heirs(id),
    await estateRepo.sources(id),
    await estateRepo.entries(id),
  );
});

void refreshEstate(WidgetRef ref, [int? id]) {
  ref.invalidate(estatesProvider);
  if (id == null) {
    ref.invalidate(estateDataProvider);
  } else {
    ref.invalidate(estateDataProvider(id));
  }
}

// ───────────── الإعدادات ─────────────
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    SharedPreferences.getInstance().then((p) {
      final v = p.getString(_key);
      if (v != null) state = ThemeMode.values.byName(v);
    });
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode m) async {
    state = m;
    (await SharedPreferences.getInstance()).setString(_key, m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
