import 'package:intl/intl.dart';

/// أدوات تنسيق التواريخ والمبالغ.
class Fmt {
  static final _money = NumberFormat('#,##0.00', 'en');

  static String money(num v, [String currency = 'ر.س']) =>
      '${_money.format(v)} $currency';

  static String date(DateTime d) =>
      normalizeDigits(DateFormat('d MMMM yyyy', 'ar').format(d));
  static String shortDate(DateTime d) =>
      normalizeDigits(DateFormat('d MMM', 'ar').format(d));
  static String time(DateTime d) =>
      normalizeDigits(DateFormat('h:mm a', 'ar').format(d));
  static String dateTime(DateTime d) => '${date(d)} - ${time(d)}';
  static String weekday(DateTime d) =>
      normalizeDigits(DateFormat('EEEE', 'ar').format(d));
  static String month(DateTime d) =>
      normalizeDigits(DateFormat('MMMM yyyy', 'ar').format(d));

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// تحويل الأرقام العربية الهندية (٠-٩) والفارسية إلى أرقام لاتينية.
  static String normalizeDigits(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = arabic.indexOf(ch);
      final j = persian.indexOf(ch);
      if (i >= 0) {
        b.write(i);
      } else if (j >= 0) {
        b.write(j);
      } else if (ch == '٫') {
        b.write('.');
      } else if (ch == '٬') {
        b.write(',');
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  /// قراءة مبلغ يكتبه المستخدم (يقبل الأرقام العربية والفواصل).
  static double? parseAmount(String s) {
    final t = normalizeDigits(s).replaceAll(',', '').trim();
    return double.tryParse(t);
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'صباح الخير';
    if (h < 18) return 'مساء الخير';
    return 'مساء النور';
  }
}
