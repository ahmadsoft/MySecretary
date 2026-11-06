import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/icons.dart';
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
      Category(
        name: 'طعام ومطاعم',
        icon: iconIndex(Icons.restaurant),
        color: 0xFFE67E22,
      ),
      Category(
        name: 'بقالة',
        icon: iconIndex(Icons.local_grocery_store),
        color: 0xFF16A085,
      ),
      Category(
        name: 'مواصلات ووقود',
        icon: iconIndex(Icons.local_gas_station),
        color: 0xFF2E86DE,
      ),
      Category(
        name: 'فواتير',
        icon: iconIndex(Icons.receipt_long),
        color: 0xFF8E44AD,
      ),
      Category(
        name: 'تسوق',
        icon: iconIndex(Icons.shopping_bag),
        color: 0xFFC0392B,
      ),
      Category(
        name: 'صحة',
        icon: iconIndex(Icons.local_hospital),
        color: 0xFF1ABC9C,
      ),
      Category(name: 'ترفيه', icon: iconIndex(Icons.movie), color: 0xFFD4AC0D),
      Category(name: 'تعليم', icon: iconIndex(Icons.school), color: 0xFF34495E),
      Category(name: 'سحب نقدي', icon: iconIndex(Icons.atm), color: 0xFF7F8C8D),
      Category(
        name: 'أخرى',
        icon: iconIndex(Icons.category),
        color: 0xFF95A5A6,
      ),
      Category(
        name: 'راتب',
        icon: iconIndex(Icons.payments),
        color: 0xFF1E6F5C,
        kind: TxKind.income,
      ),
      Category(
        name: 'تحويل وارد',
        icon: iconIndex(Icons.call_received),
        color: 0xFF27AE60,
        kind: TxKind.income,
      ),
      Category(
        name: 'دخل آخر',
        icon: iconIndex(Icons.savings),
        color: 0xFF2ECC71,
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
