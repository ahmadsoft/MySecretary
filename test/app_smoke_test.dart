import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_secretary/data/db.dart';
import 'package:my_secretary/data/models.dart';
import 'package:my_secretary/data/repository.dart';
import 'package:my_secretary/features/expenses/transaction_form.dart';
import 'package:my_secretary/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// عند التشغيل مع --dart-define=SHOTS=true --update-goldens تُحفظ لقطات الشاشات.
const shots = bool.fromEnvironment('SHOTS');

Future<void> _loadFont(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await loader.load();
}

Future<void> _seed() async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final t = TaskRepo();
  await t.insert(
    Task(
      title: 'مراجعة عقد الإيجار',
      priority: 2,
      category: 'عمل',
      dueAt: today.add(const Duration(hours: 23)),
      reminderAt: today.add(const Duration(hours: 22)),
    ),
  );
  await t.insert(
    Task(
      title: 'شراء مستلزمات البيت',
      category: 'مشتريات',
      dueAt: today.add(const Duration(hours: 23, minutes: 30)),
      repeat: Repeat.weekly,
    ),
  );
  await t.insert(
    Task(
      title: 'الاتصال بالمحاسب',
      priority: 1,
      category: 'عمل',
      dueAt: today.add(const Duration(hours: 9)),
      done: true,
      doneAt: now,
    ),
  );
  await t.insert(
    Task(
      title: 'تجديد الاستمارة',
      priority: 0,
      category: 'شخصي',
      dueAt: today.add(const Duration(days: 3, hours: 10)),
    ),
  );
  await EventRepo().insert(
    Event(
      title: 'اجتماع الفريق',
      location: 'المكتب',
      startAt: today.add(const Duration(hours: 23)),
      endAt: today.add(const Duration(hours: 23, minutes: 50)),
    ),
  );
  await NoteRepo().save(
    Note(
      title: 'أفكار المشروع',
      content: 'تطبيق لتنظيم المهام اليومية',
      pinned: true,
    ),
  );
  await NoteRepo().save(
    Note(
      title: 'قائمة الكتب',
      content: 'العادات الذرية\nفن اللامبالاة',
      color: 0xFF8E44AD,
    ),
  );

  final f = FinanceRepo();
  final cats = await f.categories();
  int cat(String n) => cats.firstWhere((c) => c.name == n).id!;
  await f.saveCategory(
    cats.firstWhere((c) => c.name == 'طعام ومطاعم').toMapCategory(budget: 800),
  );
  await f.saveTx(
    Tx(
      kind: TxKind.expense,
      amount: 45.5,
      merchant: 'STARBUCKS',
      categoryId: cat('طعام ومطاعم'),
      date: now,
      fromSms: true,
      rawSms: 'شراء عبر نقاط البيع\nمبلغ: 45.50 SAR\nلدى: STARBUCKS',
    ),
  );
  await f.saveTx(
    Tx(
      kind: TxKind.expense,
      amount: 320,
      merchant: 'بنده',
      categoryId: cat('بقالة'),
      date: now,
    ),
  );
  await f.saveTx(
    Tx(
      kind: TxKind.expense,
      amount: 150,
      merchant: 'الدريس',
      categoryId: cat('مواصلات ووقود'),
      date: now.subtract(const Duration(hours: 30)),
    ),
  );
  await f.saveTx(
    Tx(
      kind: TxKind.income,
      amount: 12500,
      merchant: 'راتب',
      categoryId: cat('راتب'),
      date: DateTime(now.year, now.month, 1),
      method: PaymentMethod.transfer,
    ),
  );

  final e = EstateRepo();
  final id = await e.saveEstate(
    Estate(name: 'تركة الوالد', deceasedName: 'عبدالله'),
  );
  final w = await e.saveHeir(
    Heir(estateId: id, name: 'أم محمد', relation: 'زوجة', share: 12.5),
  );
  await e.saveHeir(
    Heir(estateId: id, name: 'محمد', relation: 'ابن', share: 58.33),
  );
  await e.saveHeir(
    Heir(estateId: id, name: 'فاطمة', relation: 'بنت', share: 29.17),
  );
  final s1 = await e.saveSource(
    IncomeSource(estateId: id, name: 'إيجار عمارة النخيل', type: 'إيجار'),
  );
  final s2 = await e.saveSource(
    IncomeSource(estateId: id, name: 'أرباح أسهم', type: 'أرباح/استثمار'),
  );
  await e.saveEntry(
    EstateEntry(
      estateId: id,
      kind: EntryKind.income,
      amount: 60000,
      date: now,
      sourceId: s1,
    ),
  );
  await e.saveEntry(
    EstateEntry(
      estateId: id,
      kind: EntryKind.income,
      amount: 8000,
      date: now,
      sourceId: s2,
    ),
  );
  await e.saveEntry(
    EstateEntry(
      estateId: id,
      kind: EntryKind.expense,
      amount: 5000,
      date: now,
      category: 'صيانة',
    ),
  );
  await e.saveEntry(
    EstateEntry(
      estateId: id,
      kind: EntryKind.distribution,
      amount: 4000,
      date: now,
      heirId: w,
    ),
  );
}

extension on Category {
  Category toMapCategory({double? budget}) => Category(
    id: id,
    name: name,
    icon: icon,
    color: color,
    kind: kind,
    monthlyBudget: budget,
  );
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ar');
    if (shots) {
      await _loadFont(
        'Roboto',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      );
      await _loadFont(
        'MaterialIcons',
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
    }
    AppDb.overridePath = inMemoryDatabasePath;
    await _seed();
  });

  testWidgets('جميع الشاشات تعمل بدون أخطاء', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    Future<void> shot(String name) async {
      if (shots) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/$name.png'),
        );
      }
    }

    void back() =>
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();

    await tester.pumpWidget(const ProviderScope(child: MySecretaryApp()));
    await settle();
    expect(find.text('إنجاز اليوم'), findsOneWidget);
    expect(find.text('مراجعة عقد الإيجار'), findsWidgets);
    await shot('1_dashboard');

    await tester.tap(find.text('المهام').last);
    await settle();
    await shot('2_tasks');

    await tester.tap(find.text('التقويم').last);
    await settle();
    await shot('3_calendar');

    await tester.tap(find.text('المصاريف').last);
    await settle();
    expect(find.text('STARBUCKS'), findsOneWidget);
    await shot('4_expenses');

    await tester.ensureVisible(find.text('STARBUCKS'));
    await settle();
    await tester.tap(find.text('STARBUCKS'));
    await settle();
    expect(find.text('تعديل عملية'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('نص الرسالة الأصلية'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(TransactionForm),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle();
    await shot('5_transaction');
    back();
    await settle();

    await tester.tap(find.text('المزيد').last);
    await settle();
    await tester.tap(find.text('حسابات الورثة'));
    await settle();
    await tester.tap(find.text('تركة الوالد'));
    await settle();
    expect(find.text('أنصبة الورثة'), findsOneWidget);
    await shot('6_estate_summary');

    await tester.tap(find.text('الحركات'));
    await settle();
    await shot('7_estate_entries');

    await tester.tap(find.text('الورثة').last);
    await settle();
    await shot('8_estate_heirs');

    await tester.tap(find.byType(FloatingActionButton));
    await settle();
    expect(find.text('إضافة وارث'), findsOneWidget);
    back(); // إغلاق النافذة السفلية
    await settle();

    back();
    await settle();
    back();
    await settle();
    await tester.tap(find.text('الملاحظات'));
    await settle();
    await shot('9_notes');
    back();
    await settle();

    await tester.tap(find.text('رسائل البنوك'));
    await settle();
    await shot('10_sms_settings');

    back();
    await settle();
    await tester.tap(find.text('اليوم').last);
    await settle();
    await tester.tap(find.text('مهمة'));
    await settle();
    expect(find.text('مهمة جديدة'), findsOneWidget);
    await shot('11_task_form');
  });
}
