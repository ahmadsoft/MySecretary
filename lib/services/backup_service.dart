import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/format.dart';
import '../data/db.dart';
import '../data/models.dart';
import 'notification_service.dart';

/// ملخص محتوى ملف النسخة الاحتياطية (يُعرض قبل الاستعادة).
class BackupInfo {
  final DateTime? exportedAt;
  final Map<String, int> counts;
  final Map<String, dynamic> raw;
  const BackupInfo(this.exportedAt, this.counts, this.raw);

  int count(String table) => counts[table] ?? 0;
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

/// النسخ الاحتياطي الكامل لجميع بيانات التطبيق (ملف JSON واحد)
/// وتصدير المصاريف وحسابات الورثة إلى CSV يفتح في Excel / Numbers.
class BackupService {
  static const appId = 'MySecretary';
  static const formatVersion = 1;

  /// الجداول بترتيب الإدخال (الجداول الأب أولاً).
  static const tables = [
    'tasks',
    'events',
    'notes',
    'categories',
    'transactions',
    'merchant_rules',
    'estates',
    'heirs',
    'income_sources',
    'estate_entries',
  ];

  /// الإعدادات التي تُحفظ مع النسخة.
  static const _prefKeys = [
    'theme_mode',
    'sms_enabled',
    'sms_senders',
    'sms_notify',
  ];
  static const kLastBackup = 'last_backup_at';

  static const tableLabels = {
    'tasks': 'المهام',
    'events': 'المواعيد',
    'notes': 'الملاحظات',
    'categories': 'التصنيفات',
    'transactions': 'العمليات المالية',
    'merchant_rules': 'قواعد التصنيف',
    'estates': 'حسابات التركات',
    'heirs': 'الورثة',
    'income_sources': 'مصادر الإيراد',
    'estate_entries': 'حركات التركات',
  };

  // ───────────────────────── التصدير ─────────────────────────

  static Future<Map<String, dynamic>> exportMap() async {
    final db = await AppDb.instance;
    final data = <String, dynamic>{};
    for (final t in tables) {
      data[t] = await db.query(
        t,
        orderBy: t == 'merchant_rules' ? 'merchant' : 'id',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final p = <String, dynamic>{};
    for (final k in _prefKeys) {
      final v = prefs.get(k);
      if (v != null) p[k] = v;
    }
    return {
      'app': appId,
      'format': formatVersion,
      'schema': await db.getVersion(),
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
      'prefs': p,
    };
  }

  static Future<Uint8List> exportBytes() async {
    final json = const JsonEncoder.withIndent(' ').convert(await exportMap());
    return Uint8List.fromList(utf8.encode(json));
  }

  static String backupFileName([DateTime? d]) {
    final n = d ?? DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return 'MySecretary-backup-${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}.json';
  }

  static Future<void> markBackedUp() async =>
      (await SharedPreferences.getInstance()).setString(
        kLastBackup,
        DateTime.now().toIso8601String(),
      );

  static Future<DateTime?> lastBackup() async {
    final v = (await SharedPreferences.getInstance()).getString(kLastBackup);
    return v == null ? null : DateTime.tryParse(v);
  }

  // ───────────────────────── الاستعادة ─────────────────────────

  /// يقرأ الملف ويتحقق منه دون تعديل أي بيانات.
  static BackupInfo parse(List<int> bytes) {
    final dynamic j;
    try {
      j = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } catch (_) {
      throw const BackupException(
        'الملف ليس نسخة احتياطية صالحة (تعذّرت قراءته).',
      );
    }
    if (j is! Map<String, dynamic> || j['app'] != appId || j['data'] is! Map) {
      throw const BackupException(
        'هذا الملف ليس نسخة احتياطية من تطبيق سكرتيري.',
      );
    }
    final format = j['format'];
    if (format is! int || format > formatVersion) {
      throw const BackupException(
        'هذه النسخة من إصدار أحدث من التطبيق. حدّث التطبيق ثم أعد المحاولة.',
      );
    }
    final data = j['data'] as Map;
    final counts = <String, int>{};
    for (final t in tables) {
      final rows = data[t];
      if (rows == null) continue;
      if (rows is! List || rows.any((r) => r is! Map)) {
        throw BackupException('بيانات "${tableLabels[t]}" في الملف تالفة.');
      }
      counts[t] = rows.length;
    }
    return BackupInfo(DateTime.tryParse('${j['exportedAt']}'), counts, j);
  }

  /// يستبدل جميع البيانات الحالية بمحتوى النسخة الاحتياطية.
  static Future<void> restore(BackupInfo info) async {
    final db = await AppDb.instance;
    final data = info.raw['data'] as Map;

    // الأعمدة المعروفة لكل جدول (لتجاهل أي حقول غير متوقعة)
    final columns = <String, Set<String>>{};
    for (final t in tables) {
      final cols = await db.rawQuery('PRAGMA table_info($t)');
      columns[t] = {for (final c in cols) c['name'] as String};
    }

    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        for (final t in tables.reversed) {
          await txn.delete(t);
        }
        for (final t in tables) {
          final rows = data[t];
          if (rows is! List) continue;
          final b = txn.batch();
          for (final r in rows) {
            final m = <String, Object?>{};
            (r as Map).forEach((k, v) {
              if (columns[t]!.contains(k) &&
                  (v == null || v is num || v is String)) {
                m[k as String] = v;
              }
            });
            if (m.isNotEmpty) {
              b.insert(t, m, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          await b.commit(noResult: true);
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }

    // الإعدادات
    final prefs = await SharedPreferences.getInstance();
    final p = info.raw['prefs'];
    if (p is Map) {
      for (final e in p.entries) {
        final k = e.key, v = e.value;
        if (!_prefKeys.contains(k)) continue;
        if (v is bool) await prefs.setBool(k, v);
        if (v is String) await prefs.setString(k, v);
        if (v is List) {
          await prefs.setStringList(k, v.map((x) => '$x').toList());
        }
      }
    }

    await NotificationService.instance.rescheduleAll();
  }

  // ───────────────────────── CSV ─────────────────────────

  static String _csvCell(Object? v) {
    final s = '${v ?? ''}';
    if (s.contains(RegExp(r'[",\n\r]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  /// BOM في البداية ليعرض Excel الحروف العربية بشكل صحيح.
  static Uint8List _csv(List<List<Object?>> rows) => Uint8List.fromList(
    utf8.encode(
      '﻿${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}\r\n',
    ),
  );

  static String _d(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  /// جميع العمليات المالية.
  static Future<Uint8List> transactionsCsv() async {
    final db = await AppDb.instance;
    final cats = {
      for (final c in await db.query('categories')) c['id']: c['name'],
    };
    final rows = <List<Object?>>[
      [
        'التاريخ',
        'النوع',
        'المبلغ',
        'التصنيف',
        'الجهة',
        'طريقة الدفع',
        'ملاحظة',
        'المصدر',
      ],
    ];
    for (final r in await db.query('transactions', orderBy: 'date DESC')) {
      final tx = Tx.fromMap(r);
      rows.add([
        _d(r['date'] as int),
        tx.kind == TxKind.expense ? 'مصروف' : 'إيراد',
        tx.amount.toStringAsFixed(2),
        cats[tx.categoryId] ?? '',
        tx.merchant,
        paymentLabels[tx.method],
        tx.note,
        tx.fromSms ? 'رسالة بنك' : 'يدوي',
      ]);
    }
    return _csv(rows);
  }

  /// جميع حركات حسابات الورثة.
  static Future<Uint8List> estateCsv() async {
    final db = await AppDb.instance;
    final estates = {
      for (final e in await db.query('estates')) e['id']: e['name'],
    };
    final heirs = {for (final h in await db.query('heirs')) h['id']: h['name']};
    final sources = {
      for (final s in await db.query('income_sources')) s['id']: s['name'],
    };
    final rows = <List<Object?>>[
      [
        'الحساب',
        'التاريخ',
        'النوع',
        'المبلغ',
        'مصدر الإيراد',
        'بند المصروف',
        'الوارث',
        'البيان',
      ],
    ];
    for (final r in await db.query(
      'estate_entries',
      orderBy: 'estate_id, date DESC',
    )) {
      final e = EstateEntry.fromMap(r);
      rows.add([
        estates[e.estateId] ?? '',
        _d(r['date'] as int).substring(0, 10),
        entryKindLabels[e.kind],
        e.amount.toStringAsFixed(2),
        e.kind == EntryKind.income ? (sources[e.sourceId] ?? '') : '',
        e.kind == EntryKind.expense ? e.category : '',
        e.kind == EntryKind.distribution ? (heirs[e.heirId] ?? '') : '',
        e.note,
      ]);
    }
    return _csv(rows);
  }

  static String csvFileName(String kind) =>
      'MySecretary-$kind-${Fmt.normalizeDigits(DateTime.now().toIso8601String().substring(0, 10))}.csv';
}
