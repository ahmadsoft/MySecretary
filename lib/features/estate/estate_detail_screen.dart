import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/estate_calc.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'entry_form.dart';
import 'estates_screen.dart' show editEstate;

enum _Tab { summary, entries, heirs, sources }

const _tabLabels = {
  _Tab.summary: 'الملخص',
  _Tab.entries: 'الحركات',
  _Tab.heirs: 'الورثة',
  _Tab.sources: 'المصادر',
};

class EstateDetailScreen extends ConsumerStatefulWidget {
  final int estateId;
  const EstateDetailScreen({super.key, required this.estateId});

  @override
  ConsumerState<EstateDetailScreen> createState() => _EstateDetailScreenState();
}

class _EstateDetailScreenState extends ConsumerState<EstateDetailScreen> {
  _Tab _tab = _Tab.summary;
  EntryKind? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(estateDataProvider(widget.estateId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CupertinoActivityIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (d) => Scaffold(
        appBar: AppBar(
          title: Text(d.estate.name),
          actions: [
            NavIcon(
              CupertinoIcons.ellipsis_circle,
              tooltip: 'خيارات',
              onPressed: () {
                showActionSheet(context, [
                  SheetAction('نسخ التقرير', () {
                    Clipboard.setData(ClipboardData(text: _report(d)));
                    toast(
                      context,
                      'تم نسخ التقرير، يمكنك لصقه في واتساب أو أي تطبيق',
                    );
                  }, icon: CupertinoIcons.doc_on_doc),
                  SheetAction(
                    'تعديل الحساب',
                    () => editEstate(context, ref, d.estate),
                    icon: CupertinoIcons.pencil,
                  ),
                  SheetAction(
                    'حذف الحساب',
                    () async {
                      if (await confirmDialog(
                        context,
                        'حذف حساب "${d.estate.name}" وجميع حركاته؟',
                      )) {
                        await estateRepo.deleteEstate(d.estate.id!);
                        refreshEstate(ref);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: CupertinoIcons.trash,
                    destructive: true,
                  ),
                ]);
              },
            ),
            NavIcon(
              CupertinoIcons.add,
              tooltip: 'إضافة',
              onPressed: () => _add(d),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: IosSegmented<_Tab>(
                items: _tabLabels,
                value: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _Tab.summary => _summaryTab(d),
                _Tab.entries => _entriesTab(d),
                _Tab.heirs => _heirsTab(d),
                _Tab.sources => _sourcesTab(d),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _add(EstateData d) {
    switch (_tab) {
      case _Tab.heirs:
        _editHeir(d, null);
      case _Tab.sources:
        editSource(context, ref, d.estate.id!, null);
      default:
        Navigator.push(context, iosRoute(EntryForm(estateId: d.estate.id!)));
    }
  }

  // ─────────────── الملخص ───────────────
  Widget _summaryTab(EstateData d) {
    final s = d.summary;
    final sourcesSorted = s.incomeBySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catsSorted = s.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // البطاقة الرئيسية
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الرصيد المتبقي في الحساب',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    Fmt.money(s.cashBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (d.estate.deceasedName.isNotEmpty)
                  Text(
                    '${d.estate.deceasedName} رحمه الله',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
        IosSection(
          dividerIndent: 60,
          children: [
            _stat(
              'الإيرادات',
              s.totalIncome,
              CupertinoIcons.arrow_down,
              IosColors.green,
            ),
            _stat(
              'المصروفات',
              s.totalExpense,
              CupertinoIcons.arrow_up,
              IosColors.red,
            ),
            _stat(
              'صافي التركة',
              s.net,
              CupertinoIcons.equal,
              IosColors.blue,
              bold: true,
            ),
            _stat(
              'صُرف للورثة',
              s.totalDistributed,
              CupertinoIcons.person_2_fill,
              IosColors.orange,
            ),
          ],
        ),
        if (d.heirs.isNotEmpty && !s.sharesComplete)
          IosSection(
            children: [
              IosTile(
                leading: const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: IosColors.orange,
                ),
                title:
                    'مجموع الأنصبة ${s.sharesTotal.toStringAsFixed(2)}% وليس 100%',
                subtitle: 'راجع أنصبة الورثة من تبويب الورثة',
              ),
            ],
          ),
        IosSection(
          header: 'أنصبة الورثة',
          children: d.heirs.isEmpty
              ? [
                  IosTile(
                    title: 'إضافة وارث...',
                    titleColor: Ios.tint(context),
                    onTap: () => _editHeir(d, null),
                  ),
                ]
              : [
                  for (final h in s.heirs)
                    _HeirBalanceRow(b: h, onTap: () => _heirStatement(d, h)),
                ],
        ),
        IosSection(
          header: 'الإيرادات حسب المصدر',
          children: sourcesSorted.isEmpty
              ? [const IosTile(title: 'لا توجد إيرادات')]
              : [
                  for (final e in sourcesSorted)
                    _barRow(
                      d.sourceName(e.key),
                      e.value,
                      s.totalIncome,
                      IosColors.green,
                    ),
                ],
        ),
        IosSection(
          header: 'المصروفات حسب البند',
          children: catsSorted.isEmpty
              ? [const IosTile(title: 'لا توجد مصروفات')]
              : [
                  for (final e in catsSorted)
                    _barRow(e.key, e.value, s.totalExpense, IosColors.red),
                ],
        ),
      ],
    );
  }

  Widget _stat(
    String label,
    double v,
    IconData icon,
    Color color, {
    bool bold = false,
  }) => IosTile(
    leading: IconBadge(icon, color),
    title: label,
    bold: bold,
    trailing: Text(
      Fmt.money(v),
      style: TextStyle(
        fontSize: 17,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: Ios.label(context),
      ),
    ),
  );

  Widget _barRow(String label, double v, double total, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            Text(
              Fmt.money(v),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        FilterPills<EntryKind?>(
          values: const [null, ...EntryKind.values],
          selected: _filter,
          label: (k) => k == null ? 'الكل' : entryKindLabels[k]!,
          onSelected: (k) => setState(() => _filter = k),
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const SizedBox(
            height: 260,
            child: EmptyState(
              icon: CupertinoIcons.doc_text,
              message: 'لا توجد حركات',
            ),
          )
        else
          IosSection(
            dividerIndent: 62,
            children: [for (final e in list) _entryTile(d, e)],
          ),
      ],
    );
  }

  Widget _entryTile(EstateData d, EstateEntry e) {
    final (icon, color, title) = switch (e.kind) {
      EntryKind.income => (
        CupertinoIcons.arrow_down,
        IosColors.green,
        d.sourceName(e.sourceId),
      ),
      EntryKind.expense => (
        CupertinoIcons.arrow_up,
        IosColors.red,
        e.category.isEmpty ? 'أخرى' : e.category,
      ),
      EntryKind.distribution => (
        CupertinoIcons.person_fill,
        IosColors.orange,
        'صرف لـ ${d.heirName(e.heirId)}',
      ),
    };
    return IosTile(
      leading: IconBadge(icon, color, size: 34),
      title: title,
      subtitle: [
        entryKindLabels[e.kind]!,
        Fmt.date(e.date),
        if (e.note.isNotEmpty) e.note,
      ].join(' · '),
      trailing: Text(
        '${e.kind == EntryKind.income ? '+' : '-'}${Fmt.money(e.amount)}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: e.kind == EntryKind.income
              ? IosColors.green
              : Ios.label(context),
        ),
      ),
      onTap: () => Navigator.push(
        context,
        iosRoute(EntryForm(estateId: d.estate.id!, entry: e)),
      ),
    );
  }

  // ─────────────── الورثة ───────────────
  Widget _heirsTab(EstateData d) {
    if (d.heirs.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.person_2,
        message: 'أضف الورثة ونصيب كل وارث بالضغط على +',
      );
    }
    final s = d.summary;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        IosSection(
          footer:
              'مجموع الأنصبة: ${s.sharesTotal.toStringAsFixed(2)}%'
              '${s.sharesComplete ? ' ✓' : ' — يجب أن يكون 100%'}',
          dividerIndent: 70,
          children: [
            for (final b in s.heirs)
              IosTile(
                leading: _Avatar(b.heir.name),
                title: b.heir.name,
                subtitle:
                    '${b.heir.relation} · ${b.heir.share.toStringAsFixed(2)}%'
                    ' · المتبقي ${Fmt.money(b.remaining)}',
                trailing: GestureDetector(
                  onTap: () => _editHeir(d, b.heir),
                  child: Icon(
                    CupertinoIcons.info_circle,
                    color: Ios.tint(context),
                  ),
                ),
                onTap: () => _heirStatement(d, b),
              ),
          ],
        ),
      ],
    );
  }

  void _heirStatement(EstateData d, HeirBalance b) {
    final payments = d.entries
        .where((e) => e.kind == EntryKind.distribution && e.heirId == b.heir.id)
        .toList();
    showIosSheet<void>(
      context,
      DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Spacer(),
                  CupertinoButton(
                    child: const Text('تم'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Center(child: _Avatar(b.heir.name, size: 72)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                b.heir.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Ios.label(ctx),
                ),
              ),
            ),
            Center(
              child: Text(
                '${b.heir.relation} · النصيب ${b.heir.share.toStringAsFixed(2)}%',
                style: TextStyle(color: Ios.secondary(ctx)),
              ),
            ),
            const SizedBox(height: 20),
            IosSection(
              children: [
                IosTile(
                  title: 'المستحق من صافي التركة',
                  value: Fmt.money(b.entitlement),
                ),
                IosTile(title: 'ما تم صرفه', value: Fmt.money(b.paid)),
                IosTile(
                  title: 'المتبقي',
                  bold: true,
                  trailing: Text(
                    Fmt.money(b.remaining),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            IosSection(
              header: 'الدفعات',
              children: payments.isEmpty
                  ? [const IosTile(title: 'لا توجد دفعات')]
                  : [
                      for (final p in payments)
                        IosTile(
                          title: Fmt.money(p.amount),
                          subtitle: [
                            Fmt.date(p.date),
                            if (p.note.isNotEmpty) p.note,
                          ].join(' · '),
                        ),
                    ],
            ),
            IosSection(
              children: [
                IosTile(
                  title: 'تسجيل دفعة لهذا الوارث',
                  titleColor: Ios.tint(ctx),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      iosRoute(
                        EntryForm(
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
          ],
        ),
      ),
    );
  }

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

    final saved = await showIosSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> save() async {
            final v = parseShare(share.text);
            if (name.text.trim().isEmpty || v == null) {
              setS(
                () => error = v == null
                    ? 'أدخل نصيباً صحيحاً: نسبة مثل 12.5 أو كسر مثل 1/8'
                    : null,
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
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  title: h == null ? 'إضافة وارث' : 'تعديل وارث',
                  onSave: save,
                ),
                const SizedBox(height: 8),
                IosSection(
                  children: [
                    IosField(name, 'الاسم', autofocus: h == null),
                    IosTile(
                      title: 'صلة القرابة',
                      value: relation,
                      chevron: true,
                      onTap: () async {
                        final v = await pickFromList<String>(
                          ctx,
                          items: heirRelations,
                          initial: relation,
                          label: (r) => r,
                        );
                        if (v != null) setS(() => relation = v);
                      },
                    ),
                  ],
                ),
                IosSection(
                  footer: error ?? 'اكتب النسبة مثل 12.5 أو الكسر مثل 1/8',
                  children: [
                    IosField(share, 'النصيب', suffix: '%'),
                    IosField(
                      phone,
                      'رقم الجوال (اختياري)',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                if (h != null)
                  IosSection(
                    children: [
                      IosTile(
                        title: 'حذف الوارث',
                        titleColor: IosColors.red,
                        onTap: () async {
                          if (await confirmDialog(
                            ctx,
                            'حذف الوارث "${h.name}"؟',
                          )) {
                            await estateRepo.deleteHeir(h.id!);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
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
        icon: CupertinoIcons.building_2_fill,
        message: 'أضف مصادر الإيراد مثل: إيجار عمارة، بيع أرض، أرباح أسهم',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        IosSection(
          dividerIndent: 60,
          children: [
            for (final s in d.sources)
              IosTile(
                leading: const IconBadge(
                  CupertinoIcons.building_2_fill,
                  IosColors.teal,
                ),
                title: s.name,
                subtitle: [s.type, if (s.notes.isNotEmpty) s.notes].join(' · '),
                trailing: Text(
                  Fmt.money(d.summary.incomeBySource[s.id] ?? 0),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: IosColors.green,
                  ),
                ),
                onTap: () => editSource(context, ref, d.estate.id!, s),
              ),
          ],
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

/// صورة رمزية بالحرف الأول (مثل جهات الاتصال في iPhone).
class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar(this.name, {this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [Color(0xFFA5A9B4), Color(0xFF858993)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Text(
      name.isEmpty ? '?' : name.characters.first,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.42,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _HeirBalanceRow extends StatelessWidget {
  final HeirBalance b;
  final VoidCallback onTap;
  const _HeirBalanceRow({required this.b, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ratio = b.entitlement <= 0
        ? 0.0
        : (b.paid / b.entitlement).clamp(0.0, 1.0);
    final sec = TextStyle(fontSize: 13, color: Ios.secondary(context));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            _Avatar(b.heir.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.heir.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text('${b.heir.share.toStringAsFixed(2)}%', style: sec),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    color: IosColors.orange,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text('المستحق ${Fmt.money(b.entitlement)}', style: sec),
                      Text(
                        'المتبقي ${Fmt.money(b.remaining)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Ios.label(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

  final result = await showIosSheet<int>(
    context,
    StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: s == null ? 'مصدر إيراد جديد' : 'تعديل المصدر',
              onSave: () async {
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
            ),
            const SizedBox(height: 8),
            IosSection(
              footer: 'مثال: إيجار عمارة حي النخيل',
              children: [
                IosField(name, 'اسم المصدر', autofocus: s == null),
                IosTile(
                  title: 'النوع',
                  value: type,
                  chevron: true,
                  onTap: () async {
                    final v = await pickFromList<String>(
                      ctx,
                      items: incomeSourceTypes,
                      initial: type,
                      label: (t) => t,
                    );
                    if (v != null) setS(() => type = v);
                  },
                ),
                IosField(notes, 'ملاحظات (مثل اسم المستأجر)'),
              ],
            ),
            if (s != null)
              IosSection(
                children: [
                  IosTile(
                    title: 'حذف المصدر',
                    titleColor: IosColors.red,
                    onTap: () async {
                      if (await confirmDialog(
                        ctx,
                        'حذف المصدر؟ ستبقى الإيرادات المرتبطة به بدون مصدر.',
                      )) {
                        await estateRepo.deleteSource(s.id!);
                        if (ctx.mounted) Navigator.pop(ctx, -1);
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
  if (result != null) refreshEstate(ref, estateId);
  return result != null && result > 0 ? result : null;
}
