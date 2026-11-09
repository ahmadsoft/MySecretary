import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_secretary/data/db.dart';
import 'package:my_secretary/data/estate_calc.dart';
import 'package:my_secretary/data/models.dart';
import 'package:my_secretary/data/repository.dart';
import 'package:my_secretary/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'sms_senders': ['AlRajhiBank'],
    });
    await AppDb.close();
    AppDb.overridePath = inMemoryDatabasePath;
  });

  Future<int> seed() async {
    final t = TaskRepo();
    final parent = await t.insert(
      Task(title: 'مهمة رئيسية', dueAt: DateTime(2026, 11, 10, 9)),
    );
    await t.insert(Task(title: 'مهمة فرعية', parentId: parent));
    await EventRepo().insert(
      Event(
        title: 'اجتماع',
        startAt: DateTime(2026, 11, 10),
        endAt: DateTime(2026, 11, 10, 1),
      ),
    );
    await NoteRepo().save(Note(title: 'ملاحظة', content: 'سطر 1\nسطر "2"'));
    final f = FinanceRepo();
    final cat = (await f.categories()).first;
    await f.saveTx(
      Tx(
        kind: TxKind.expense,
        amount: 45.5,
        merchant: 'STARBUCKS, Riyadh',
        categoryId: cat.id,
        date: DateTime(2026, 11, 5),
      ),
    );
    final e = EstateRepo();
    final id = await e.saveEstate(Estate(name: 'تركة الوالد'));
    final h = await e.saveHeir(Heir(estateId: id, name: 'محمد', share: 100));
    final s = await e.saveSource(IncomeSource(estateId: id, name: 'إيجار'));
    await e.saveEntry(
      EstateEntry(
        estateId: id,
        kind: EntryKind.income,
        amount: 1000,
        date: DateTime(2026, 1, 1),
        sourceId: s,
      ),
    );
    await e.saveEntry(
      EstateEntry(
        estateId: id,
        kind: EntryKind.distribution,
        amount: 300,
        date: DateTime(2026, 1, 2),
        heirId: h,
      ),
    );
    return id;
  }

  test('النسخ والاستعادة يعيدان جميع البيانات كما هي', () async {
    final estateId = await seed();
    final before = await BackupService.exportMap();
    final bytes = await BackupService.exportBytes();

    // تخريب البيانات الحالية
    final db = await AppDb.instance;
    await db.delete('notes');
    await db.delete('estates');
    await TaskRepo().insert(Task(title: 'مهمة لم تكن في النسخة'));
    (await SharedPreferences.getInstance()).setString('theme_mode', 'light');

    final info = BackupService.parse(bytes);
    expect(info.count('tasks'), 2);
    expect(info.count('estate_entries'), 2);
    await BackupService.restore(info);

    final after = await BackupService.exportMap();
    expect(after['data'], before['data']);
    expect(
      (await SharedPreferences.getInstance()).getString('theme_mode'),
      'dark',
    );

    // الروابط بين الجداول سليمة بعد الاستعادة
    final r = EstateRepo();
    final s = EstateSummary.compute(
      await r.heirs(estateId),
      await r.entries(estateId),
    );
    expect(s.heirs.single.remaining, 700);
    final tasks = await TaskRepo().all();
    expect(tasks.where((t) => t.parentId != null).single.title, 'مهمة فرعية');

    // الإضافة بعد الاستعادة تعمل (لا تعارض في أرقام المعرّفات)
    expect(await TaskRepo().insert(Task(title: 'جديدة')), greaterThan(2));
  });

  test('رفض الملفات غير الصالحة', () {
    expect(
      () => BackupService.parse(utf8.encode('not json')),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => BackupService.parse(utf8.encode('{"app":"Other","data":{}}')),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => BackupService.parse(
        utf8.encode('{"app":"MySecretary","format":99,"data":{}}'),
      ),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => BackupService.parse(
        utf8.encode('{"app":"MySecretary","format":1,"data":{"tasks":5}}'),
      ),
      throwsA(isA<BackupException>()),
    );
  });

  test('تصدير CSV مع حماية الفواصل وعلامات التنصيص', () async {
    await seed();
    final txBytes = await BackupService.transactionsCsv();
    expect(txBytes.sublist(0, 3), [
      0xEF,
      0xBB,
      0xBF,
    ]); // BOM ليقرأ Excel العربية
    final tx = utf8.decode(txBytes);
    expect(tx, contains('"STARBUCKS, Riyadh"'));
    expect(tx, contains('45.50'));
    final es = utf8.decode(await BackupService.estateCsv());
    expect(es, contains('تركة الوالد'));
    expect(es, contains('إيجار'));
    expect(es.trim().split('\r\n').length, 3);
  });
}
