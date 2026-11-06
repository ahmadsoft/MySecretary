import 'package:flutter_test/flutter_test.dart';
import 'package:my_secretary/data/estate_calc.dart';
import 'package:my_secretary/data/models.dart';

void main() {
  test('parseShare يقبل النسبة والكسر', () {
    expect(parseShare('12.5'), 12.5);
    expect(parseShare('1/8'), 12.5);
    expect(parseShare('٢٥٪'.replaceAll('٪', '%')), 25);
    expect(parseShare('0'), isNull);
    expect(parseShare('abc'), isNull);
    expect(parseShare('3/0'), isNull);
  });

  test('حساب ملخص التركة وأنصبة الورثة', () {
    final heirs = [
      Heir(id: 1, estateId: 1, name: 'زوجة', share: 12.5),
      Heir(id: 2, estateId: 1, name: 'ابن', share: 58.33),
      Heir(id: 3, estateId: 1, name: 'بنت', share: 29.17),
    ];
    final d = DateTime(2026, 1, 1);
    final entries = [
      EstateEntry(
        estateId: 1,
        kind: EntryKind.income,
        amount: 10000,
        date: d,
        sourceId: 7,
      ),
      EstateEntry(
        estateId: 1,
        kind: EntryKind.income,
        amount: 2000,
        date: d,
        sourceId: 8,
      ),
      EstateEntry(
        estateId: 1,
        kind: EntryKind.expense,
        amount: 2000,
        date: d,
        category: 'صيانة',
      ),
      EstateEntry(
        estateId: 1,
        kind: EntryKind.distribution,
        amount: 1000,
        date: d,
        heirId: 1,
      ),
    ];
    final s = EstateSummary.compute(heirs, entries);
    expect(s.totalIncome, 12000);
    expect(s.net, 10000);
    expect(s.cashBalance, 9000);
    expect(s.incomeBySource[7], 10000);
    expect(s.expenseByCategory['صيانة'], 2000);
    expect(s.sharesComplete, isTrue);
    expect(s.heirs[0].entitlement, 1250);
    expect(s.heirs[0].remaining, 250);
    expect(s.heirs[1].paid, 0);
  });
}
