// نماذج البيانات لجميع أقسام التطبيق.

int? _ms(DateTime? d) => d?.millisecondsSinceEpoch;
DateTime? _dt(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

// ───────────────────────── المهام ─────────────────────────

enum Repeat { none, daily, weekly, monthly }

const repeatLabels = {
  Repeat.none: 'بدون تكرار',
  Repeat.daily: 'يومي',
  Repeat.weekly: 'أسبوعي',
  Repeat.monthly: 'شهري',
};

const priorityLabels = ['منخفضة', 'متوسطة', 'عالية'];

const defaultTaskCategories = ['عمل', 'شخصي', 'البيت', 'مشتريات', 'أخرى'];

class Task {
  final int? id;
  final String title;
  final String notes;
  final int priority; // 0 منخفضة، 1 متوسطة، 2 عالية
  final String category;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final Repeat repeat;
  final bool done;
  final DateTime? doneAt;
  final int? parentId;
  final DateTime createdAt;

  Task({
    this.id,
    required this.title,
    this.notes = '',
    this.priority = 1,
    this.category = 'شخصي',
    this.dueAt,
    this.reminderAt,
    this.repeat = Repeat.none,
    this.done = false,
    this.doneAt,
    this.parentId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'notes': notes,
    'priority': priority,
    'category': category,
    'due_at': _ms(dueAt),
    'reminder_at': _ms(reminderAt),
    'repeat': repeat.name,
    'done': done ? 1 : 0,
    'done_at': _ms(doneAt),
    'parent_id': parentId,
    'created_at': _ms(createdAt),
  };

  factory Task.fromMap(Map<String, Object?> m) => Task(
    id: m['id'] as int?,
    title: m['title'] as String,
    notes: (m['notes'] as String?) ?? '',
    priority: (m['priority'] as int?) ?? 1,
    category: (m['category'] as String?) ?? 'شخصي',
    dueAt: _dt(m['due_at']),
    reminderAt: _dt(m['reminder_at']),
    repeat: Repeat.values.byName((m['repeat'] as String?) ?? 'none'),
    done: m['done'] == 1,
    doneAt: _dt(m['done_at']),
    parentId: m['parent_id'] as int?,
    createdAt: _dt(m['created_at']),
  );

  Task copyWith({
    int? id,
    String? title,
    String? notes,
    int? priority,
    String? category,
    DateTime? dueAt,
    bool clearDue = false,
    DateTime? reminderAt,
    bool clearReminder = false,
    Repeat? repeat,
    bool? done,
    DateTime? doneAt,
    int? parentId,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    priority: priority ?? this.priority,
    category: category ?? this.category,
    dueAt: clearDue ? null : (dueAt ?? this.dueAt),
    reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
    repeat: repeat ?? this.repeat,
    done: done ?? this.done,
    doneAt: doneAt ?? this.doneAt,
    parentId: parentId ?? this.parentId,
    createdAt: createdAt,
  );

  bool get isOverdue =>
      !done && dueAt != null && dueAt!.isBefore(DateTime.now());
}

/// يحسب الموعد التالي للمهمة المتكررة.
DateTime nextOccurrence(DateTime d, Repeat r) {
  switch (r) {
    case Repeat.daily:
      return d.add(const Duration(days: 1));
    case Repeat.weekly:
      return d.add(const Duration(days: 7));
    case Repeat.monthly:
      final m = d.month == 12 ? 1 : d.month + 1;
      final y = d.month == 12 ? d.year + 1 : d.year;
      final lastDay = DateTime(y, m + 1, 0).day;
      return DateTime(
        y,
        m,
        d.day > lastDay ? lastDay : d.day,
        d.hour,
        d.minute,
      );
    case Repeat.none:
      return d;
  }
}

// ───────────────────────── المواعيد ─────────────────────────

class Event {
  final int? id;
  final String title;
  final String location;
  final String notes;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final int? reminderMinutes; // قبل الموعد بكم دقيقة
  final int color;

  Event({
    this.id,
    required this.title,
    this.location = '',
    this.notes = '',
    required this.startAt,
    required this.endAt,
    this.allDay = false,
    this.reminderMinutes = 30,
    this.color = 0xFF007AFF,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'location': location,
    'notes': notes,
    'start_at': _ms(startAt),
    'end_at': _ms(endAt),
    'all_day': allDay ? 1 : 0,
    'reminder_minutes': reminderMinutes,
    'color': color,
  };

  factory Event.fromMap(Map<String, Object?> m) => Event(
    id: m['id'] as int?,
    title: m['title'] as String,
    location: (m['location'] as String?) ?? '',
    notes: (m['notes'] as String?) ?? '',
    startAt: _dt(m['start_at'])!,
    endAt: _dt(m['end_at'])!,
    allDay: m['all_day'] == 1,
    reminderMinutes: m['reminder_minutes'] as int?,
    color: (m['color'] as int?) ?? 0xFF007AFF,
  );
}

const reminderOptions = <int?, String>{
  null: 'بدون تذكير',
  0: 'وقت الموعد',
  10: 'قبل 10 دقائق',
  30: 'قبل 30 دقيقة',
  60: 'قبل ساعة',
  1440: 'قبل يوم',
};

// ───────────────────────── الملاحظات ─────────────────────────

class Note {
  final int? id;
  final String title;
  final String content;
  final int color;
  final bool pinned;
  final DateTime updatedAt;

  Note({
    this.id,
    this.title = '',
    this.content = '',
    this.color = 0xFFFFCC00,
    this.pinned = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'color': color,
    'pinned': pinned ? 1 : 0,
    'updated_at': _ms(updatedAt),
  };

  factory Note.fromMap(Map<String, Object?> m) => Note(
    id: m['id'] as int?,
    title: (m['title'] as String?) ?? '',
    content: (m['content'] as String?) ?? '',
    color: (m['color'] as int?) ?? 0xFFFFCC00,
    pinned: m['pinned'] == 1,
    updatedAt: _dt(m['updated_at']),
  );
}

// ───────────────────────── المصاريف ─────────────────────────

enum TxKind { expense, income }

enum PaymentMethod { cash, card, transfer }

const paymentLabels = {
  PaymentMethod.cash: 'نقداً',
  PaymentMethod.card: 'بطاقة',
  PaymentMethod.transfer: 'تحويل',
};

class Category {
  final int? id;
  final String name;
  final int icon; // رقم الأيقونة في categoryIcons
  final int color;
  final TxKind kind;
  final double? monthlyBudget;

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.kind = TxKind.expense,
    this.monthlyBudget,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'kind': kind.name,
    'budget': monthlyBudget,
  };

  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as int?,
    name: m['name'] as String,
    icon: m['icon'] as int,
    color: m['color'] as int,
    kind: TxKind.values.byName(m['kind'] as String),
    monthlyBudget: (m['budget'] as num?)?.toDouble(),
  );
}

class Tx {
  final int? id;
  final TxKind kind;
  final double amount;
  final int? categoryId;
  final String merchant;
  final String note;
  final DateTime date;
  final PaymentMethod method;
  final bool fromSms;
  final String? smsHash;
  final String? rawSms;

  Tx({
    this.id,
    required this.kind,
    required this.amount,
    this.categoryId,
    this.merchant = '',
    this.note = '',
    required this.date,
    this.method = PaymentMethod.card,
    this.fromSms = false,
    this.smsHash,
    this.rawSms,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'amount': amount,
    'category_id': categoryId,
    'merchant': merchant,
    'note': note,
    'date': _ms(date),
    'method': method.name,
    'from_sms': fromSms ? 1 : 0,
    'sms_hash': smsHash,
    'raw_sms': rawSms,
  };

  factory Tx.fromMap(Map<String, Object?> m) => Tx(
    id: m['id'] as int?,
    kind: TxKind.values.byName(m['kind'] as String),
    amount: (m['amount'] as num).toDouble(),
    categoryId: m['category_id'] as int?,
    merchant: (m['merchant'] as String?) ?? '',
    note: (m['note'] as String?) ?? '',
    date: _dt(m['date'])!,
    method: PaymentMethod.values.byName((m['method'] as String?) ?? 'card'),
    fromSms: m['from_sms'] == 1,
    smsHash: m['sms_hash'] as String?,
    rawSms: m['raw_sms'] as String?,
  );
}

// ───────────────────────── حسابات الورثة ─────────────────────────

class Estate {
  final int? id;
  final String name; // اسم الحساب، مثل: تركة الوالد
  final String deceasedName;
  final String notes;
  final DateTime createdAt;

  Estate({
    this.id,
    required this.name,
    this.deceasedName = '',
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'deceased_name': deceasedName,
    'notes': notes,
    'created_at': _ms(createdAt),
  };

  factory Estate.fromMap(Map<String, Object?> m) => Estate(
    id: m['id'] as int?,
    name: m['name'] as String,
    deceasedName: (m['deceased_name'] as String?) ?? '',
    notes: (m['notes'] as String?) ?? '',
    createdAt: _dt(m['created_at']),
  );
}

class Heir {
  final int? id;
  final int estateId;
  final String name;
  final String relation;
  final double share; // النسبة المئوية من صافي التركة
  final String phone;

  Heir({
    this.id,
    required this.estateId,
    required this.name,
    this.relation = '',
    required this.share,
    this.phone = '',
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'estate_id': estateId,
    'name': name,
    'relation': relation,
    'share': share,
    'phone': phone,
  };

  factory Heir.fromMap(Map<String, Object?> m) => Heir(
    id: m['id'] as int?,
    estateId: m['estate_id'] as int,
    name: m['name'] as String,
    relation: (m['relation'] as String?) ?? '',
    share: (m['share'] as num).toDouble(),
    phone: (m['phone'] as String?) ?? '',
  );
}

const heirRelations = [
  'زوجة',
  'زوج',
  'ابن',
  'بنت',
  'أب',
  'أم',
  'أخ',
  'أخت',
  'جد',
  'جدة',
  'أخرى',
];

class IncomeSource {
  final int? id;
  final int estateId;
  final String name; // مثل: إيجار عمارة حي النخيل
  final String type;
  final String notes;

  IncomeSource({
    this.id,
    required this.estateId,
    required this.name,
    this.type = 'إيجار',
    this.notes = '',
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'estate_id': estateId,
    'name': name,
    'type': type,
    'notes': notes,
  };

  factory IncomeSource.fromMap(Map<String, Object?> m) => IncomeSource(
    id: m['id'] as int?,
    estateId: m['estate_id'] as int,
    name: m['name'] as String,
    type: (m['type'] as String?) ?? 'أخرى',
    notes: (m['notes'] as String?) ?? '',
  );
}

const incomeSourceTypes = [
  'إيجار',
  'بيع أصل',
  'أرباح/استثمار',
  'رصيد بنكي',
  'تعويض/مستحقات',
  'أخرى',
];

const estateExpenseCategories = [
  'صيانة',
  'رسوم حكومية',
  'زكاة',
  'سداد دين',
  'وصية',
  'أتعاب/محاماة',
  'خدمات وفواتير',
  'أخرى',
];

enum EntryKind { income, expense, distribution }

const entryKindLabels = {
  EntryKind.income: 'إيراد',
  EntryKind.expense: 'مصروف',
  EntryKind.distribution: 'صرف لوارث',
};

class EstateEntry {
  final int? id;
  final int estateId;
  final EntryKind kind;
  final double amount;
  final DateTime date;
  final int? sourceId; // للإيراد: من أين
  final int? heirId; // للصرف لوارث
  final String category; // للمصروف
  final String note;

  EstateEntry({
    this.id,
    required this.estateId,
    required this.kind,
    required this.amount,
    required this.date,
    this.sourceId,
    this.heirId,
    this.category = '',
    this.note = '',
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'estate_id': estateId,
    'kind': kind.name,
    'amount': amount,
    'date': _ms(date),
    'source_id': sourceId,
    'heir_id': heirId,
    'category': category,
    'note': note,
  };

  factory EstateEntry.fromMap(Map<String, Object?> m) => EstateEntry(
    id: m['id'] as int?,
    estateId: m['estate_id'] as int,
    kind: EntryKind.values.byName(m['kind'] as String),
    amount: (m['amount'] as num).toDouble(),
    date: _dt(m['date'])!,
    sourceId: m['source_id'] as int?,
    heirId: m['heir_id'] as int?,
    category: (m['category'] as String?) ?? '',
    note: (m['note'] as String?) ?? '',
  );
}
