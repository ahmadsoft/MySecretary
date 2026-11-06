import 'package:flutter_test/flutter_test.dart';
import 'package:my_secretary/data/db.dart';
import 'package:my_secretary/data/estate_calc.dart';
import 'package:my_secretary/data/models.dart';
import 'package:my_secretary/data/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDb.close();
    AppDb.overridePath = inMemoryDatabasePath;
  });

  test('إنشاء القاعدة وتعبئة التصنيفات الافتراضية', () async {
    final cats = await FinanceRepo().categories();
    expect(cats.length, 13);
    expect(cats.where((c) => c.kind == TxKind.income).length, 3);
  });

  test('المهام: إضافة وحذف مع المهام الفرعية', () async {
    final r = TaskRepo();
    final id = await r.insert(
      Task(title: 'اجتماع', dueAt: DateTime(2026, 11, 6, 10)),
    );
    await r.insert(Task(title: 'تحضير العرض', parentId: id));
    expect((await r.all()).length, 2);
    await r.delete(id);
    expect(await r.all(), isEmpty);
  });

  test('التكرار الشهري يحافظ على نهاية الشهر', () {
    expect(
      nextOccurrence(DateTime(2026, 1, 31, 9), Repeat.monthly),
      DateTime(2026, 2, 28, 9),
    );
    expect(
      nextOccurrence(DateTime(2026, 12, 15), Repeat.monthly),
      DateTime(2027, 1, 15),
    );
  });

  test('المصاريف: تعلم تصنيف التاجر ومنع تكرار الرسالة', () async {
    final r = FinanceRepo();
    final cats = await r.categories();
    final health = cats.firstWhere((c) => c.name == 'صحة');
    final food = cats.firstWhere((c) => c.name == 'طعام ومطاعم');

    // اقتراح بالكلمات المفتاحية
    expect(
      await r.suggestCategory(
        'STARBUCKS RIYADH',
        TxKind.expense,
        PaymentMethod.card,
      ),
      food.id,
    );

    // بعد أن يصنفه المستخدم يدوياً يتعلم التطبيق
    await r.saveTx(
      Tx(
        kind: TxKind.expense,
        amount: 30,
        merchant: 'Shop 123',
        categoryId: health.id,
        date: DateTime.now(),
      ),
    );
    expect(
      await r.suggestCategory('SHOP 123', TxKind.expense, PaymentMethod.card),
      health.id,
    );

    await r.saveTx(
      Tx(
        kind: TxKind.expense,
        amount: 10,
        date: DateTime.now(),
        smsHash: 'abc',
        fromSms: true,
      ),
      learnRule: false,
    );
    expect(await r.smsExists('abc'), isTrue);
    expect(await r.smsExists('zzz'), isFalse);

    final now = DateTime.now();
    final month = await r.transactions(
      from: DateTime(now.year, now.month),
      to: DateTime(now.year, now.month + 1),
    );
    expect(month.length, 2);
  });

  test('حسابات الورثة: دورة كاملة', () async {
    final r = EstateRepo();
    final eid = await r.saveEstate(Estate(name: 'تركة الوالد'));
    final wife = await r.saveHeir(
      Heir(estateId: eid, name: 'أم محمد', relation: 'زوجة', share: 12.5),
    );
    await r.saveHeir(
      Heir(estateId: eid, name: 'محمد', relation: 'ابن', share: 87.5),
    );
    final rent = await r.saveSource(
      IncomeSource(estateId: eid, name: 'إيجار عمارة', type: 'إيجار'),
    );
    final d = DateTime(2026, 3, 1);
    await r.saveEntry(
      EstateEntry(
        estateId: eid,
        kind: EntryKind.income,
        amount: 40000,
        date: d,
        sourceId: rent,
      ),
    );
    await r.saveEntry(
      EstateEntry(
        estateId: eid,
        kind: EntryKind.expense,
        amount: 8000,
        date: d,
        category: 'صيانة',
      ),
    );
    await r.saveEntry(
      EstateEntry(
        estateId: eid,
        kind: EntryKind.distribution,
        amount: 3000,
        date: d,
        heirId: wife,
      ),
    );

    final s = EstateSummary.compute(await r.heirs(eid), await r.entries(eid));
    expect(s.net, 32000);
    expect(s.cashBalance, 29000);
    expect(s.incomeBySource[rent], 40000);
    expect(s.heirs.first.entitlement, 4000);
    expect(s.heirs.first.remaining, 1000);

    // حذف الحساب يحذف كل ما يتبعه
    await r.deleteEstate(eid);
    expect(await r.heirs(eid), isEmpty);
    expect(await r.entries(eid), isEmpty);
  });
}
