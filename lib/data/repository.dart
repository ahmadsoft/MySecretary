import 'package:sqflite/sqflite.dart';

import '../services/sms_parser.dart';
import 'db.dart';
import 'models.dart';

Map<String, Object?> _noId(Map<String, Object?> m) => m..remove('id');

// ───────────────────────── المهام ─────────────────────────
class TaskRepo {
  Future<Database> get _db => AppDb.instance;

  Future<List<Task>> all() async {
    final rows = await (await _db).query(
      'tasks',
      orderBy: 'done ASC, due_at IS NULL, due_at ASC, priority DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<int> insert(Task t) async =>
      (await _db).insert('tasks', _noId(t.toMap()));

  Future<void> update(Task t) async =>
      (await _db).update('tasks', t.toMap(), where: 'id=?', whereArgs: [t.id]);

  Future<void> delete(int id) async => (await _db).delete(
    'tasks',
    where: 'id=? OR parent_id=?',
    whereArgs: [id, id],
  );

  Future<Task?> byId(int id) async {
    final r = await (await _db).query('tasks', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Task.fromMap(r.first);
  }
}

// ───────────────────────── المواعيد ─────────────────────────
class EventRepo {
  Future<Database> get _db => AppDb.instance;

  Future<List<Event>> all() async => (await (await _db).query(
    'events',
    orderBy: 'start_at ASC',
  )).map(Event.fromMap).toList();

  Future<int> insert(Event e) async =>
      (await _db).insert('events', _noId(e.toMap()));

  Future<void> update(Event e) async =>
      (await _db).update('events', e.toMap(), where: 'id=?', whereArgs: [e.id]);

  Future<void> delete(int id) async =>
      (await _db).delete('events', where: 'id=?', whereArgs: [id]);
}

// ───────────────────────── الملاحظات ─────────────────────────
class NoteRepo {
  Future<Database> get _db => AppDb.instance;

  Future<List<Note>> all() async => (await (await _db).query(
    'notes',
    orderBy: 'pinned DESC, updated_at DESC',
  )).map(Note.fromMap).toList();

  Future<int> save(Note n) async {
    final db = await _db;
    if (n.id == null) return db.insert('notes', _noId(n.toMap()));
    await db.update('notes', n.toMap(), where: 'id=?', whereArgs: [n.id]);
    return n.id!;
  }

  Future<void> delete(int id) async =>
      (await _db).delete('notes', where: 'id=?', whereArgs: [id]);
}

// ───────────────────────── المصاريف ─────────────────────────
class FinanceRepo {
  Future<Database> get _db => AppDb.instance;

  Future<List<Category>> categories() async => (await (await _db).query(
    'categories',
    orderBy: 'kind, id',
  )).map(Category.fromMap).toList();

  Future<int> saveCategory(Category c) async {
    final db = await _db;
    if (c.id == null) return db.insert('categories', _noId(c.toMap()));
    await db.update('categories', c.toMap(), where: 'id=?', whereArgs: [c.id]);
    return c.id!;
  }

  Future<void> deleteCategory(int id) async =>
      (await _db).delete('categories', where: 'id=?', whereArgs: [id]);

  Future<List<Tx>> transactions({DateTime? from, DateTime? to}) async {
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('date < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await (await _db).query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC',
    );
    return rows.map(Tx.fromMap).toList();
  }

  Future<int> saveTx(Tx t, {bool learnRule = true}) async {
    final db = await _db;
    final int id;
    if (t.id == null) {
      id = await db.insert('transactions', _noId(t.toMap()));
    } else {
      await db.update(
        'transactions',
        t.toMap(),
        where: 'id=?',
        whereArgs: [t.id],
      );
      id = t.id!;
    }
    // تعلّم التصنيف: نفس التاجر يُصنف تلقائياً في المرات القادمة
    if (learnRule && t.merchant.isNotEmpty && t.categoryId != null) {
      await db.insert('merchant_rules', {
        'merchant': SmsParser.normalizeMerchant(t.merchant),
        'category_id': t.categoryId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return id;
  }

  Future<void> deleteTx(int id) async =>
      (await _db).delete('transactions', where: 'id=?', whereArgs: [id]);

  Future<bool> smsExists(String hash) async => (await (await _db).query(
    'transactions',
    columns: ['id'],
    where: 'sms_hash=?',
    whereArgs: [hash],
  )).isNotEmpty;

  /// يقترح تصنيفاً حسب التاجر (قاعدة متعلمة) أو حسب كلمات مفتاحية.
  Future<int?> suggestCategory(
    String merchant,
    TxKind kind,
    PaymentMethod method,
  ) async {
    final db = await _db;
    final cats = await categories();
    int? byName(String n) {
      for (final c in cats) {
        if (c.name == n && c.kind == kind) return c.id;
      }
      return null;
    }

    if (merchant.isNotEmpty) {
      final r = await db.query(
        'merchant_rules',
        where: 'merchant=?',
        whereArgs: [SmsParser.normalizeMerchant(merchant)],
      );
      if (r.isNotEmpty) return r.first['category_id'] as int?;
    }
    if (kind == TxKind.income) {
      return method == PaymentMethod.transfer
          ? byName('تحويل وارد')
          : byName('دخل آخر');
    }
    if (method == PaymentMethod.cash) return byName('سحب نقدي');
    final m = merchant.toLowerCase();
    const hints = {
      'طعام ومطاعم': [
        'مطعم',
        'كافيه',
        'cafe',
        'coffee',
        'starbucks',
        'mcdonald',
        'kfc',
        'burger',
        'pizza',
        'albaik',
        'البيك',
        'هرفي',
        'herfy',
        'restaurant',
        'jahez',
        'جاهز',
        'hungerstation',
        'هنقرستيشن',
      ],
      'بقالة': [
        'panda',
        'بنده',
        'othaim',
        'العثيم',
        'danube',
        'الدانوب',
        'carrefour',
        'كارفور',
        'lulu',
        'لولو',
        'tamimi',
        'التميمي',
        'سوبرماركت',
        'market',
        'تموينات',
        'بقالة',
      ],
      'مواصلات ووقود': [
        'aldrees',
        'الدريس',
        'petromin',
        'بترومين',
        'sasco',
        'ساسكو',
        'naft',
        'وقود',
        'محطة',
        'uber',
        'careem',
        'كريم',
        'fuel',
        'parking',
      ],
      'فواتير': [
        'stc',
        'mobily',
        'موبايلي',
        'zain',
        'زين',
        'كهرباء',
        'electricity',
        'مياه',
        'water',
        'سداد',
        'sadad',
      ],
      'صحة': [
        'صيدلية',
        'pharmacy',
        'nahdi',
        'النهدي',
        'الدواء',
        'مستشفى',
        'hospital',
        'clinic',
        'عيادة',
      ],
      'تسوق': [
        'jarir',
        'جرير',
        'extra',
        'اكسترا',
        'amazon',
        'noon',
        'نون',
        'ikea',
        'ايكيا',
        'centrepoint',
        'mall',
      ],
      'ترفيه': [
        'cinema',
        'سينما',
        'vox',
        'netflix',
        'shahid',
        'شاهد',
        'spotify',
        'playstation',
      ],
    };
    for (final e in hints.entries) {
      if (e.value.any(m.contains)) return byName(e.key);
    }
    return byName('أخرى');
  }
}

// ───────────────────────── حسابات الورثة ─────────────────────────
class EstateRepo {
  Future<Database> get _db => AppDb.instance;

  Future<List<Estate>> estates() async => (await (await _db).query(
    'estates',
    orderBy: 'created_at DESC',
  )).map(Estate.fromMap).toList();

  Future<Estate?> estateById(int id) async {
    final r = await (await _db).query(
      'estates',
      where: 'id=?',
      whereArgs: [id],
    );
    return r.isEmpty ? null : Estate.fromMap(r.first);
  }

  Future<int> saveEstate(Estate e) async {
    final db = await _db;
    if (e.id == null) return db.insert('estates', _noId(e.toMap()));
    await db.update('estates', e.toMap(), where: 'id=?', whereArgs: [e.id]);
    return e.id!;
  }

  Future<void> deleteEstate(int id) async =>
      (await _db).delete('estates', where: 'id=?', whereArgs: [id]);

  Future<List<Heir>> heirs(int estateId) async => (await (await _db).query(
    'heirs',
    where: 'estate_id=?',
    whereArgs: [estateId],
    orderBy: 'id',
  )).map(Heir.fromMap).toList();

  Future<int> saveHeir(Heir h) async {
    final db = await _db;
    if (h.id == null) return db.insert('heirs', _noId(h.toMap()));
    await db.update('heirs', h.toMap(), where: 'id=?', whereArgs: [h.id]);
    return h.id!;
  }

  Future<void> deleteHeir(int id) async =>
      (await _db).delete('heirs', where: 'id=?', whereArgs: [id]);

  Future<List<IncomeSource>> sources(int estateId) async =>
      (await (await _db).query(
        'income_sources',
        where: 'estate_id=?',
        whereArgs: [estateId],
        orderBy: 'id',
      )).map(IncomeSource.fromMap).toList();

  Future<int> saveSource(IncomeSource s) async {
    final db = await _db;
    if (s.id == null) return db.insert('income_sources', _noId(s.toMap()));
    await db.update(
      'income_sources',
      s.toMap(),
      where: 'id=?',
      whereArgs: [s.id],
    );
    return s.id!;
  }

  Future<void> deleteSource(int id) async =>
      (await _db).delete('income_sources', where: 'id=?', whereArgs: [id]);

  Future<List<EstateEntry>> entries(int estateId) async =>
      (await (await _db).query(
        'estate_entries',
        where: 'estate_id=?',
        whereArgs: [estateId],
        orderBy: 'date DESC, id DESC',
      )).map(EstateEntry.fromMap).toList();

  Future<int> saveEntry(EstateEntry e) async {
    final db = await _db;
    if (e.id == null) return db.insert('estate_entries', _noId(e.toMap()));
    await db.update(
      'estate_entries',
      e.toMap(),
      where: 'id=?',
      whereArgs: [e.id],
    );
    return e.id!;
  }

  Future<void> deleteEntry(int id) async =>
      (await _db).delete('estate_entries', where: 'id=?', whereArgs: [id]);
}
