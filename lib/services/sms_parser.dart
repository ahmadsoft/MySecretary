import '../core/format.dart';
import '../data/models.dart';

/// نتيجة تحليل رسالة بنكية.
class ParsedSms {
  final TxKind kind;
  final double amount;
  final String merchant;
  final PaymentMethod method;
  const ParsedSms(this.kind, this.amount, this.merchant, this.method);

  @override
  String toString() => 'ParsedSms($kind, $amount, "$merchant", $method)';
}

/// يحلل رسائل البنوك (عربي/إنجليزي) لاستخراج المبلغ ونوع العملية والتاجر.
class SmsParser {
  static const _ignore = [
    'رمز التحقق',
    'رمز التفعيل',
    'كلمة المرور',
    'رمز الدخول',
    'لا تشارك',
    'otp',
    'one time password',
    'verification code',
    'passcode',
    'مرفوضة',
    'رفض',
    'declined',
    'failed',
    'لم تتم',
    'غير ناجحة',
  ];

  static const _income = [
    'إيداع',
    'ايداع',
    'راتب',
    'حوالة واردة',
    'تحويل وارد',
    'وارد',
    'دائن',
    'استرداد',
    'مسترد',
    'استلام',
    'أضيف',
    'اضيف',
    'credited',
    'credit',
    'deposit',
    'received',
    'refund',
    'salary',
    'incoming',
  ];

  static const _expense = [
    'شراء',
    'خصم',
    'سحب',
    'دفع',
    'مدفوعات',
    'سداد',
    'مدين',
    'حوالة صادرة',
    'تحويل صادر',
    'صادر',
    'نقاط البيع',
    'مدى',
    'purchase',
    'debited',
    'debit',
    'withdrawal',
    'withdrawn',
    'spent',
    'pos',
    'payment',
    'paid',
    'outgoing',
    'atm',
  ];

  static const _currency =
      r'(?:SAR|SR|ر\.?\s?س\.?|ريال|ريالا|AED|درهم|KWD|د\.?\s?ك|QAR|ر\.?\s?ق|BHD|د\.?\s?ب|OMR|ر\.?\s?ع|EGP|جنيه|ج\.?\s?م|JOD|دينار|USD|دولار|\$|EUR|€)';
  static const _number = r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)';

  static final _amountAfterCur = RegExp(
    '$_currency\\s*:?\\s*$_number',
    caseSensitive: false,
  );
  static final _amountBeforeCur = RegExp(
    '$_number\\s*$_currency',
    caseSensitive: false,
  );
  static final _amountLabel = RegExp(
    '(?:المبلغ|مبلغ|بمبلغ|قيمة|amount|amt)\\s*:?\\s*(?:$_currency)?\\s*:?\\s*$_number',
    caseSensitive: false,
  );

  static final _merchantLine = RegExp(
    r'^\s*(?:لدى|لدي|عند|التاجر|المتجر|الجهة|إلى|الى|من|at|merchant|to|from)\s*[:：\-]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _merchantInline = RegExp(
    r'(?:لدى|لدي|عند|at)\s*[:：]?\s*([^\n,،]+?)(?:\s+(?:في|بتاريخ|on|بطاقة|card|using|الرصيد|balance)(?=\s|$)|[\n,،.]\s|[\n,،]|$)',
    caseSensitive: false,
  );

  /// يعيد null إذا لم تكن الرسالة عملية مالية.
  static ParsedSms? parse(String raw) {
    final body = Fmt.normalizeDigits(raw);
    final lower = body.toLowerCase();

    if (_ignore.any((k) => lower.contains(k))) return null;

    final amount = _findAmount(body);
    if (amount == null || amount <= 0) return null;

    final kind = _detectKind(lower);
    if (kind == null) return null;

    return ParsedSms(kind, amount, _findMerchant(body), _detectMethod(lower));
  }

  static bool _isBalanceLine(String l) {
    final s = l.toLowerCase();
    return s.contains('رصيد') ||
        s.contains('balance') ||
        s.contains('المتاح') ||
        s.contains('available') ||
        s.contains('الحد') ||
        s.contains('limit') ||
        s.contains('رسوم') ||
        s.contains('fee');
  }

  static double? _toDouble(String s) => double.tryParse(s.replaceAll(',', ''));

  static double? _findAmount(String body) {
    final lines = body.split(RegExp(r'[\n\r]+'));
    // 1) سطر يحتوي كلمة "مبلغ/amount"
    for (final l in lines) {
      final m = _amountLabel.firstMatch(l);
      if (m != null) return _toDouble(m.group(1)!);
    }
    // 2) أول مبلغ مع عملة في سطر لا يخص الرصيد
    for (final l in lines) {
      if (_isBalanceLine(l)) {
        // قد يحتوي السطر على المبلغ والرصيد معاً؛ نأخذ ما قبل كلمة الرصيد
        final cut = l.toLowerCase().indexOf(
          RegExp(r'رصيد|balance|المتاح|available'),
        );
        if (cut <= 0) continue;
        final v = _currencyAmount(l.substring(0, cut));
        if (v != null) return v;
        continue;
      }
      final v = _currencyAmount(l);
      if (v != null) return v;
    }
    return null;
  }

  static double? _currencyAmount(String l) {
    final a = _amountAfterCur.firstMatch(l);
    final b = _amountBeforeCur.firstMatch(l);
    if (a == null && b == null) return null;
    if (a == null) return _toDouble(b!.group(1)!);
    if (b == null) return _toDouble(a.group(1)!);
    return _toDouble(a.start <= b.start ? a.group(1)! : b.group(1)!);
  }

  static TxKind? _detectKind(String lower) {
    int first(List<String> keys) {
      var best = -1;
      for (final k in keys) {
        final i = _wordIndex(lower, k);
        if (i >= 0 && (best < 0 || i < best)) best = i;
      }
      return best;
    }

    final i = first(_income);
    final e = first(_expense);
    if (i < 0 && e < 0) return null;
    if (i < 0) return TxKind.expense;
    if (e < 0) return TxKind.income;
    return i < e ? TxKind.income : TxKind.expense; // الكلمة الأسبق تحدد النوع
  }

  /// يبحث عن الكلمة كاملة للكلمات اللاتينية القصيرة (مثل pos و atm).
  static int _wordIndex(String text, String key) {
    if (RegExp(r'^[a-z]+$').hasMatch(key)) {
      final m = RegExp('\\b$key\\b').firstMatch(text);
      return m?.start ?? -1;
    }
    return text.indexOf(key);
  }

  static PaymentMethod _detectMethod(String lower) {
    if (lower.contains('سحب') ||
        lower.contains('صراف') ||
        lower.contains('atm') ||
        lower.contains('withdraw')) {
      return PaymentMethod.cash;
    }
    if (lower.contains('حوالة') ||
        lower.contains('تحويل') ||
        lower.contains('transfer') ||
        lower.contains('سداد')) {
      return PaymentMethod.transfer;
    }
    return PaymentMethod.card;
  }

  static String _findMerchant(String body) {
    for (final l in body.split(RegExp(r'[\n\r]+'))) {
      final m = _merchantLine.firstMatch(l);
      if (m != null) {
        final v = _clean(m.group(1)!);
        if (v.isNotEmpty && !_looksLikeAmountOrDate(v)) return v;
      }
    }
    final m = _merchantInline.firstMatch(body);
    if (m != null) {
      final v = _clean(m.group(1)!);
      if (v.isNotEmpty && !_looksLikeAmountOrDate(v)) return v;
    }
    return '';
  }

  static String _clean(String s) {
    var v = s.trim();
    v = v.replaceAll(RegExp(r'\s+'), ' ');
    if (v.length > 40) v = v.substring(0, 40).trim();
    return v;
  }

  static bool _looksLikeAmountOrDate(String v) =>
      RegExp(r'^[\d\s/:.\-*]+$').hasMatch(v) ||
      _amountAfterCur.hasMatch(v) ||
      _amountBeforeCur.hasMatch(v);

  /// تجزئة ثابتة (FNV-1a) لمنع تسجيل نفس الرسالة مرتين.
  static String hash(String sender, int dateMs, String body) {
    var h = 0x811c9dc5;
    for (final c in '$sender|$dateMs|$body'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  /// يوحد اسم التاجر لاستخدامه في قواعد التصنيف التلقائي.
  static String normalizeMerchant(String m) => m
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
