import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// قاعدة البيانات المحلية (SQLite). جميع البيانات تبقى على الجهاز.
class AppDb {
  AppDb._();
  static Database? _db;
  static String? overridePath; // للاختبارات

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final path =
        overridePath ?? p.join(await getDatabasesPath(), 'my_secretary.db');
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        final b = db.batch();
        _createSchema(b);
        await b.commit(noResult: true);
        await _seed(db);
      },
    );
    return _db!;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static void _createSchema(Batch b) {
    b.execute('''CREATE TABLE tasks(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL, notes TEXT, priority INTEGER, category TEXT,
      due_at INTEGER, reminder_at INTEGER, repeat TEXT, done INTEGER DEFAULT 0,
      done_at INTEGER, parent_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE,
      created_at INTEGER)''');
    b.execute(
      '''CREATE TABLE events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL, location TEXT, notes TEXT, start_at INTEGER NOT NULL,
      end_at INTEGER NOT NULL, all_day INTEGER, reminder_minutes INTEGER, color INTEGER)''',
    );
    b.execute(
      '''CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT, content TEXT, color INTEGER, pinned INTEGER, updated_at INTEGER)''',
    );
    b.execute(
      '''CREATE TABLE categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, icon INTEGER, color INTEGER, kind TEXT, budget REAL)''',
    );
    b.execute('''CREATE TABLE transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kind TEXT NOT NULL, amount REAL NOT NULL,
      category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      merchant TEXT, note TEXT, date INTEGER NOT NULL, method TEXT,
      from_sms INTEGER DEFAULT 0, sms_hash TEXT UNIQUE, raw_sms TEXT)''');
    b.execute('CREATE INDEX tx_date ON transactions(date)');
    b.execute('''CREATE TABLE merchant_rules(
      merchant TEXT PRIMARY KEY,
      category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE)''');
    b.execute(
      '''CREATE TABLE estates(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, deceased_name TEXT, notes TEXT, created_at INTEGER)''',
    );
    b.execute('''CREATE TABLE heirs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      estate_id INTEGER NOT NULL REFERENCES estates(id) ON DELETE CASCADE,
      name TEXT NOT NULL, relation TEXT, share REAL NOT NULL, phone TEXT)''');
    b.execute('''CREATE TABLE income_sources(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      estate_id INTEGER NOT NULL REFERENCES estates(id) ON DELETE CASCADE,
      name TEXT NOT NULL, type TEXT, notes TEXT)''');
    b.execute('''CREATE TABLE estate_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      estate_id INTEGER NOT NULL REFERENCES estates(id) ON DELETE CASCADE,
      kind TEXT NOT NULL, amount REAL NOT NULL, date INTEGER NOT NULL,
      source_id INTEGER REFERENCES income_sources(id) ON DELETE SET NULL,
      heir_id INTEGER REFERENCES heirs(id) ON DELETE SET NULL,
      category TEXT, note TEXT)''');
  }

  static Future<void> _seed(Database db) async {
    final cats = [
      Category(name: 'طعام ومطاعم', icon: 0, color: 0xFFFF9500),
      Category(name: 'بقالة', icon: 1, color: 0xFF34C759),
      Category(name: 'مواصلات ووقود', icon: 2, color: 0xFF007AFF),
      Category(name: 'فواتير', icon: 3, color: 0xFF5856D6),
      Category(name: 'تسوق', icon: 4, color: 0xFFFF2D55),
      Category(name: 'صحة', icon: 5, color: 0xFFFF3B30),
      Category(name: 'ترفيه', icon: 6, color: 0xFFAF52DE),
      Category(name: 'تعليم', icon: 7, color: 0xFF30B0C7),
      Category(name: 'سحب نقدي', icon: 8, color: 0xFF8E8E93),
      Category(name: 'أخرى', icon: 9, color: 0xFFA2845E),
      Category(name: 'راتب', icon: 10, color: 0xFF34C759, kind: TxKind.income),
      Category(
        name: 'تحويل وارد',
        icon: 11,
        color: 0xFF00C7BE,
        kind: TxKind.income,
      ),
      Category(
        name: 'دخل آخر',
        icon: 12,
        color: 0xFF32ADE6,
        kind: TxKind.income,
      ),
    ];
    final b = db.batch();
    for (final c in cats) {
      b.insert('categories', c.toMap()..remove('id'));
    }
    await b.commit(noResult: true);
  }
}
