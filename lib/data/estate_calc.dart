import '../core/format.dart';
import 'models.dart';

/// ملخص وضع وارث واحد.
class HeirBalance {
  final Heir heir;
  final double entitlement; // نصيبه من الصافي
  final double paid; // ما صُرف له
  double get remaining => entitlement - paid;
  const HeirBalance(this.heir, this.entitlement, this.paid);
}

/// ملخص حساب التركة.
class EstateSummary {
  final double totalIncome;
  final double totalExpense;
  final double totalDistributed;
  final Map<int?, double> incomeBySource; // sourceId -> مجموع
  final Map<String, double> expenseByCategory;
  final List<HeirBalance> heirs;
  final double sharesTotal;

  /// صافي التركة القابل للقسمة = الإيرادات - المصروفات
  double get net => totalIncome - totalExpense;

  /// الرصيد النقدي المتبقي في الحساب بعد الصرف للورثة
  double get cashBalance => net - totalDistributed;

  bool get sharesComplete => (sharesTotal - 100).abs() < 0.01;

  const EstateSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalDistributed,
    required this.incomeBySource,
    required this.expenseByCategory,
    required this.heirs,
    required this.sharesTotal,
  });

  factory EstateSummary.compute(List<Heir> heirs, List<EstateEntry> entries) {
    double inc = 0, exp = 0, dist = 0;
    final bySource = <int?, double>{};
    final byCat = <String, double>{};
    final paid = <int, double>{};
    for (final e in entries) {
      switch (e.kind) {
        case EntryKind.income:
          inc += e.amount;
          bySource[e.sourceId] = (bySource[e.sourceId] ?? 0) + e.amount;
        case EntryKind.expense:
          exp += e.amount;
          final c = e.category.isEmpty ? 'أخرى' : e.category;
          byCat[c] = (byCat[c] ?? 0) + e.amount;
        case EntryKind.distribution:
          dist += e.amount;
          if (e.heirId != null) {
            paid[e.heirId!] = (paid[e.heirId!] ?? 0) + e.amount;
          }
      }
    }
    final net = inc - exp;
    return EstateSummary(
      totalIncome: inc,
      totalExpense: exp,
      totalDistributed: dist,
      incomeBySource: bySource,
      expenseByCategory: byCat,
      sharesTotal: heirs.fold(0.0, (s, h) => s + h.share),
      heirs: [
        for (final h in heirs)
          HeirBalance(h, net * h.share / 100, paid[h.id] ?? 0),
      ],
    );
  }
}

/// يقرأ النصيب بصيغة نسبة مئوية (12.5) أو كسر (1/8).
/// يعيد النسبة المئوية أو null إذا كانت الصيغة غير صحيحة.
double? parseShare(String input) {
  final s = Fmt.normalizeDigits(input).replaceAll('%', '').trim();
  if (s.isEmpty) return null;
  if (s.contains('/')) {
    final parts = s.split('/');
    if (parts.length != 2) return null;
    final a = double.tryParse(parts[0].trim());
    final b = double.tryParse(parts[1].trim());
    if (a == null || b == null || b == 0) return null;
    final v = a / b * 100;
    return v > 0 && v <= 100 ? v : null;
  }
  final v = double.tryParse(s);
  return v != null && v > 0 && v <= 100 ? v : null;
}
