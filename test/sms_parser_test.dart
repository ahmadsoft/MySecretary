import 'package:flutter_test/flutter_test.dart';
import 'package:my_secretary/data/models.dart';
import 'package:my_secretary/services/sms_parser.dart';

void main() {
  group('SmsParser', () {
    test('شراء عبر نقاط البيع بالعربي', () {
      final r = SmsParser.parse(
        'شراء عبر نقاط البيع\nبطاقة: **1234\nمبلغ: 45.50 SAR\nلدى: STARBUCKS RIYADH\nفي: 2026-11-05 10:22\nالرصيد: 3,250.00 SAR',
      );
      expect(r, isNotNull);
      expect(r!.kind, TxKind.expense);
      expect(r.amount, 45.50);
      expect(r.merchant, 'STARBUCKS RIYADH');
      expect(r.method, PaymentMethod.card);
    });

    test('مبلغ قبل العملة وأرقام عربية', () {
      final r = SmsParser.parse('تم خصم ١٢٠٫٧٥ ر.س من حسابك لدى بنده في 05/11');
      expect(r!.kind, TxKind.expense);
      expect(r.amount, 120.75);
      expect(r.merchant, 'بنده');
    });

    test('إيداع راتب', () {
      final r = SmsParser.parse(
        'إيداع راتب\nالمبلغ: SAR 12,500.00\nالحساب: ***5678\nالرصيد: SAR 15,000.00',
      );
      expect(r!.kind, TxKind.income);
      expect(r.amount, 12500);
    });

    test('English purchase', () {
      final r = SmsParser.parse(
        'Purchase of SAR 89.00 at JARIR BOOKSTORE on 05/11/26 using card **1234. Available balance SAR 1,000.00',
      );
      expect(r!.kind, TxKind.expense);
      expect(r.amount, 89);
      expect(r.merchant, 'JARIR BOOKSTORE');
    });

    test('سحب صراف', () {
      final r = SmsParser.parse('سحب نقدي من صراف آلي\nمبلغ: 500 SAR');
      expect(r!.kind, TxKind.expense);
      expect(r.method, PaymentMethod.cash);
      expect(r.amount, 500);
    });

    test('حوالة واردة', () {
      final r = SmsParser.parse(
        'حوالة واردة\nمبلغ: 1,000.00 ر.س\nمن: محمد أحمد',
      );
      expect(r!.kind, TxKind.income);
      expect(r.amount, 1000);
      expect(r.merchant, 'محمد أحمد');
      expect(r.method, PaymentMethod.transfer);
    });

    test('تجاهل رسائل رمز التحقق', () {
      expect(
        SmsParser.parse('رمز التحقق 4455 لعملية شراء بمبلغ 50 SAR'),
        isNull,
      );
    });

    test('تجاهل رسائل بدون مبلغ', () {
      expect(SmsParser.parse('مرحباً بك في تطبيق البنك'), isNull);
    });

    test('تجاهل العمليات المرفوضة', () {
      expect(SmsParser.parse('عملية شراء مرفوضة بمبلغ 300 SAR'), isNull);
    });

    test('التجزئة ثابتة', () {
      expect(SmsParser.hash('BANK', 1, 'x'), SmsParser.hash('BANK', 1, 'x'));
      expect(
        SmsParser.hash('BANK', 1, 'x') == SmsParser.hash('BANK', 2, 'x'),
        isFalse,
      );
    });
  });
}
