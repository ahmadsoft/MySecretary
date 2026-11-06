import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/estate_calc.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'entry_form.dart';
import 'estates_screen.dart' show editEstate;

const _green = Color(0xFF1E8449);
const _red = Color(0xFFC0392B);
const _blue = Color(0xFF2E86DE);

class EstateDetailScreen extends ConsumerStatefulWidget {
  final int estateId;
  const EstateDetailScreen({super.key, required this.estateId});

  @override
  ConsumerState<EstateDetailScreen> createState() => _EstateDetailScreenState();
}

class _EstateDetailScreenState extends ConsumerState<EstateDetailScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this)
    ..addListener(() => setState(() {}));
  EntryKind? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(estateDataProvider(widget.estateId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (d) => Scaffold(
        appBar: AppBar(
          title: Text(d.estate.name),
          actions: [
            IconButton(
              tooltip: 'نسخ التقرير',
              icon: const Icon(Icons.copy_all),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _report(d)));
                toast(
                  context,
                  'تم نسخ التقرير، يمكنك لصقه في واتساب أو أي تطبيق',
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') await editEstate(context, ref, d.estate);
                if (!context.mounted) return;
                if (v == 'delete' &&
                    await confirmDialog(
                      context,
                      'حذف حساب "${d.estate.name}" وجميع حركاته؟',
                    )) {
                  await estateRepo.deleteEstate(d.estate.id!);
                  refreshEstate(ref);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('تعديل الحساب')),
                PopupMenuItem(value: 'delete', child: Text('حذف الحساب')),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'الملخص'),
              Tab(text: 'الحركات'),
              Tab(text: 'الورثة'),
              Tab(text: 'مصادر الإيراد'),
            ],
          ),
        ),
        floatingActionButton: _fab(d),
        body: TabBarView(
          controller: _tabs,
          children: [
            _summaryTab(d),
            _entriesTab(d),
            _heirsTab(d),
            _sourcesTab(d),
          ],
        ),
      ),
    );
  }

  Widget _fab(EstateData d) {
    switch (_tabs.index) {
      case 2:
        return FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => _editHeir(d, null),
          icon: const Icon(Icons.person_add),
          label: const Text('وارث'),
        );
      case 3:
        return FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => editSource(context, ref, d.estate.id!, null),
          icon: const Icon(Icons.add),
          label: const Text('مصدر إيراد'),
        );
      default:
        return FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EntryForm(estateId: d.estate.id!),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('حركة'),
        );
    }
  }

  // ─────────────── الملخص ───────────────
  Widget _summaryTab(EstateData d) {
    final s = d.summary;
    final c = Theme.of(context).colorScheme;
    Widget stat(String label, double v, Color color, IconData icon) => Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.outline, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(
                  Fmt.money(v),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final sourcesSorted = s.incomeBySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catsSorted = s.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      children: [
        Row(
          children: [
            stat('الإيرادات', s.totalIncome, _green, Icons.arrow_downward),
            stat('المصروفات', s.totalExpense, _red, Icons.arrow_upward),
          ],
        ),
        Row(
          children: [
            stat('صافي التركة', s.net, c.primary, Icons.account_balance),
            stat('صُرف للورثة', s.totalDistributed, _blue, Icons.people),
          ],
        ),
        Card(
          margin: const EdgeInsets.all(4),
          color: c.primaryContainer,
          child: ListTile(
            leading: Icon(Icons.savings, color: c.onPrimaryContainer),
            title: Text(
              'الرصيد المتبقي في الحساب',
              style: TextStyle(color: c.onPrimaryContainer),
            ),
            trailing: Text(
              Fmt.money(s.cashBalance),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: c.onPrimaryContainer,
              ),
            ),
          ),
        ),
        if (d.heirs.isNotEmpty && !s.sharesComplete)
          Card(
            margin: const EdgeInsets.all(4),
            color: c.errorContainer,
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: c.onErrorContainer),
              title: Text(
                'مجموع أنصبة الورثة ${s.sharesTotal.toStringAsFixed(2)}% وليس 100%. راجع الأنصبة.',
                style: TextStyle(color: c.onErrorContainer),
              ),
            ),
          ),
        const SectionTitle('أنصبة الورثة'),
        if (d.heirs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('لم تتم إضافة ورثة بعد (من تبويب الورثة).'),
          ),
        for (final h in s.heirs) _HeirBalanceCard(b: h),
        const SectionTitle('الإيرادات حسب المصدر'),
        if (sourcesSorted.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد إيرادات'),
          ),
        for (final e in sourcesSorted)
          _barRow(d.sourceName(e.key), e.value, s.totalIncome, _green),
        const SectionTitle('المصروفات حسب البند'),
        if (catsSorted.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد مصروفات'),
          ),
        for (final e in catsSorted)
          _barRow(e.key, e.value, s.totalExpense, _red),
      ],
    );
  }

  Widget _barRow(String label, double v, double total, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              Fmt.money(v),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total == 0 ? 0 : v / total,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    ),
  );

  // ─────────────── الحركات ───────────────
  Widget _entriesTab(EstateData d) {
    final list = _filter == null
        ? d.entries
        : d.entries.where((e) => e.kind == _filter).toList();
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              for (final k in [null, ...EntryKind.values])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(k == null ? 'الكل' : entryKindLabels[k]!),
                    selected: _filter == k,
                    onSelected: (_) => setState(() => _filter = k),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long,
                  message: 'لا توجد حركات',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [for (final e in list) _entryTile(d, e)],
                ),
        ),
      ],
    );
  }

  Widget _entryTile(EstateData d, EstateEntry e) {
    final (icon, color, title) = switch (e.kind) {
      EntryKind.income => (
        Icons.arrow_downward,
        _green,
        'إيراد من: ${d.sourceName(e.sourceId)}',
      ),
      EntryKind.expense => (
        Icons.arrow_upward,
        _red,
        'مصروف: ${e.category.isEmpty ? 'أخرى' : e.category}',
      ),
      EntryKind.distribution => (
        Icons.person,
        _blue,
        'صرف للوارث: ${d.heirName(e.heirId)}',
      ),
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [Fmt.date(e.date), if (e.note.isNotEmpty) e.note].join(' • '),
        ),
        trailing: Text(
          '${e.kind == EntryKind.income ? '+' : '-'}${Fmt.money(e.amount)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EntryForm(estateId: d.estate.id!, entry: e),
          ),
        ),
      ),
    );
  }

  // ─────────────── الورثة ───────────────
  Widget _heirsTab(EstateData d) {
    if (d.heirs.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        message: 'أضف الورثة ونصيب كل وارث',
      );
    }
    final s = d.summary;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'مجموع الأنصبة: ${s.sharesTotal.toStringAsFixed(2)}%',
            style: TextStyle(
              color: s.sharesComplete
                  ? _green
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        for (final b in s.heirs)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(b.heir.name.characters.first)),
              title: Text(
                b.heir.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${b.heir.relation} • النصيب ${b.heir.share.toStringAsFixed(2)}%'
                '\nالمتبقي له: ${Fmt.money(b.remaining)}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editHeir(d, b.heir),
              ),
              onTap: () => _heirStatement(d, b),
            ),
          ),
      ],
    );
  }

  void _heirStatement(EstateData d, HeirBalance b) {
    final payments = d.entries
        .where((e) => e.kind == EntryKind.distribution && e.heirId == b.heir.id)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'كشف حساب: ${b.heir.name}',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _kv('النصيب', '${b.heir.share.toStringAsFixed(2)}%'),
            _kv('المستحق من صافي التركة', Fmt.money(b.entitlement)),
            _kv('ما تم صرفه', Fmt.money(b.paid)),
            _kv('المتبقي', Fmt.money(b.remaining), bold: true),
            const Divider(height: 24),
            const Text(
              'الدفعات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('لا توجد دفعات'),
              ),
            for (final p in payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(Fmt.money(p.amount)),
                subtitle: Text(
                  [Fmt.date(p.date), if (p.note.isNotEmpty) p.note].join(' • '),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.payments),
              label: const Text('تسجيل دفعة لهذا الوارث'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EntryForm(
                      estateId: d.estate.id!,
                      initialKind: EntryKind.distribution,
                      initialHeirId: b.heir.id,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(k)),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Future<void> _editHeir(EstateData d, Heir? h) async {
    final name = TextEditingController(text: h?.name);
    final share = TextEditingController(
      text: h == null ? '' : _fmtShare(h.share),
    );
    final phone = TextEditingController(text: h?.phone);
    var relation = h?.relation.isNotEmpty == true
        ? h!.relation
        : heirRelations.first;
    if (!heirRelations.contains(relation)) relation = 'أخرى';
    String? error;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                h == null ? 'إضافة وارث' : 'تعديل وارث',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                autofocus: h == null,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: relation,
                decoration: const InputDecoration(labelText: 'صلة القرابة'),
                items: [
                  for (final r in heirRelations)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => relation = v!,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: share,
                decoration: InputDecoration(
                  labelText: 'النصيب',
                  hintText: 'نسبة مثل 12.5 أو كسر مثل 1/8',
                  suffixText: '%',
                  errorText: error,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال (اختياري)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (h != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف'),
                      onPressed: () async {
                        if (await confirmDialog(
                          ctx,
                          'حذف الوارث "${h.name}"؟',
                        )) {
                          await estateRepo.deleteHeir(h.id!);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        }
                      },
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final v = parseShare(share.text);
                      if (name.text.trim().isEmpty || v == null) {
                        setS(
                          () => error = v == null ? 'أدخل نصيباً صحيحاً' : null,
                        );
                        return;
                      }
                      await estateRepo.saveHeir(
                        Heir(
                          id: h?.id,
                          estateId: d.estate.id!,
                          name: name.text.trim(),
                          relation: relation,
                          share: v,
                          phone: phone.text.trim(),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) refreshEstate(ref, d.estate.id);
  }

  String _fmtShare(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');

  // ─────────────── مصادر الإيراد ───────────────
  Widget _sourcesTab(EstateData d) {
    if (d.sources.isEmpty) {
      return const EmptyState(
        icon: Icons.apartment,
        message: 'أضف مصادر الإيراد مثل: إيجار عمارة، بيع أرض، أرباح أسهم',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      children: [
        for (final s in d.sources)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.apartment)),
              title: Text(
                s.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [s.type, if (s.notes.isNotEmpty) s.notes].join(' • '),
              ),
              trailing: Text(
                Fmt.money(d.summary.incomeBySource[s.id] ?? 0),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _green,
                ),
              ),
              onTap: () => editSource(context, ref, d.estate.id!, s),
            ),
          ),
      ],
    );
  }

  // ─────────────── التقرير النصي ───────────────
  String _report(EstateData d) {
    final s = d.summary;
    final b = StringBuffer()
      ..writeln('📋 تقرير ${d.estate.name}')
      ..writeln(
        d.estate.deceasedName.isNotEmpty
            ? 'المتوفى: ${d.estate.deceasedName} رحمه الله'
            : '',
      )
      ..writeln('التاريخ: ${Fmt.date(DateTime.now())}')
      ..writeln('')
      ..writeln('إجمالي الإيرادات: ${Fmt.money(s.totalIncome)}');
    for (final e in s.incomeBySource.entries) {
      b.writeln('  • ${d.sourceName(e.key)}: ${Fmt.money(e.value)}');
    }
    b.writeln('إجمالي المصروفات: ${Fmt.money(s.totalExpense)}');
    for (final e in s.expenseByCategory.entries) {
      b.writeln('  • ${e.key}: ${Fmt.money(e.value)}');
    }
    b
      ..writeln('صافي التركة: ${Fmt.money(s.net)}')
      ..writeln('المصروف للورثة: ${Fmt.money(s.totalDistributed)}')
      ..writeln('الرصيد المتبقي: ${Fmt.money(s.cashBalance)}')
      ..writeln('')
      ..writeln('أنصبة الورثة:');
    for (final h in s.heirs) {
      b.writeln(
        '  • ${h.heir.name} (${h.heir.relation} - ${h.heir.share.toStringAsFixed(2)}%): '
        'المستحق ${Fmt.money(h.entitlement)}، المصروف ${Fmt.money(h.paid)}، المتبقي ${Fmt.money(h.remaining)}',
      );
    }
    b.writeln('\n— من تطبيق سكرتيري');
    return b.toString();
  }
}

class _HeirBalanceCard extends StatelessWidget {
  final HeirBalance b;
  const _HeirBalanceCard({required this.b});

  Widget _line(String k, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
        Text(
          v,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ratio = b.entitlement <= 0
        ? 0.0
        : (b.paid / b.entitlement).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${b.heir.name} (${b.heir.relation})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${b.heir.share.toStringAsFixed(2)}%'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: _blue,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            _line('المستحق', Fmt.money(b.entitlement)),
            _line('المصروف له', Fmt.money(b.paid)),
            _line('المتبقي', Fmt.money(b.remaining), bold: true),
          ],
        ),
      ),
    );
  }
}

/// إضافة/تعديل مصدر إيراد. يعيد رقم المصدر عند الحفظ.
Future<int?> editSource(
  BuildContext context,
  WidgetRef ref,
  int estateId,
  IncomeSource? s,
) async {
  final name = TextEditingController(text: s?.name);
  final notes = TextEditingController(text: s?.notes);
  var type = s?.type ?? incomeSourceTypes.first;
  if (!incomeSourceTypes.contains(type)) type = 'أخرى';
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s == null ? 'مصدر إيراد جديد' : 'تعديل المصدر'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم المصدر',
                hintText: 'مثال: إيجار عمارة حي النخيل',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: [
                for (final t in incomeSourceTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => type = v!,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (مثل اسم المستأجر)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (s != null)
          TextButton(
            onPressed: () async {
              if (await confirmDialog(
                ctx,
                'حذف المصدر؟ ستبقى الإيرادات المرتبطة به بدون مصدر.',
              )) {
                await estateRepo.deleteSource(s.id!);
                if (ctx.mounted) Navigator.pop(ctx, -1);
              }
            },
            child: const Text('حذف'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final id = await estateRepo.saveSource(
              IncomeSource(
                id: s?.id,
                estateId: estateId,
                name: name.text.trim(),
                type: type,
                notes: notes.text.trim(),
              ),
            );
            if (ctx.mounted) Navigator.pop(ctx, id);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  if (result != null) refreshEstate(ref, estateId);
  return result != null && result > 0 ? result : null;
}
