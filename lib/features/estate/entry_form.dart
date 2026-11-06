import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'estate_detail_screen.dart' show editSource;

/// تسجيل حركة على حساب التركة: إيراد (مع مصدره) أو مصروف أو صرف لوارث.
class EntryForm extends ConsumerStatefulWidget {
  final int estateId;
  final EstateEntry? entry;
  final EntryKind? initialKind;
  final int? initialHeirId;
  const EntryForm({
    super.key,
    required this.estateId,
    this.entry,
    this.initialKind,
    this.initialHeirId,
  });

  @override
  ConsumerState<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<EntryForm> {
  late EntryKind _kind =
      widget.entry?.kind ?? widget.initialKind ?? EntryKind.income;
  late final _amount = TextEditingController(
    text: widget.entry == null ? '' : widget.entry!.amount.toStringAsFixed(2),
  );
  late final _note = TextEditingController(text: widget.entry?.note);
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  late int? _sourceId = widget.entry?.sourceId;
  late int? _heirId = widget.entry?.heirId ?? widget.initialHeirId;
  late String _category = (widget.entry?.category.isNotEmpty ?? false)
      ? widget.entry!.category
      : estateExpenseCategories.first;

  Future<void> _save() async {
    final amount = Fmt.parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      toast(context, 'أدخل مبلغاً صحيحاً');
      return;
    }
    if (_kind == EntryKind.income && _sourceId == null) {
      toast(context, 'حدد مصدر الإيراد');
      return;
    }
    if (_kind == EntryKind.distribution && _heirId == null) {
      toast(context, 'اختر الوارث');
      return;
    }
    await estateRepo.saveEntry(
      EstateEntry(
        id: widget.entry?.id,
        estateId: widget.estateId,
        kind: _kind,
        amount: amount,
        date: _date,
        sourceId: _kind == EntryKind.income ? _sourceId : null,
        heirId: _kind == EntryKind.distribution ? _heirId : null,
        category: _kind == EntryKind.expense ? _category : '',
        note: _note.text.trim(),
      ),
    );
    refreshEstate(ref, widget.estateId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(estateDataProvider(widget.estateId)).value;
    final sources = d?.sources ?? const <IncomeSource>[];
    final heirs = d?.summary.heirs ?? const [];
    final editing = widget.entry != null;
    final cats = {...estateExpenseCategories, _category}.toList();
    final source = sources.where((s) => s.id == _sourceId).firstOrNull;
    final heir = heirs.where((h) => h.heir.id == _heirId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل حركة' : 'حركة جديدة'),
        actions: [NavTextButton(editing ? 'تم' : 'إضافة', onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: IosSegmented<EntryKind>(
              items: entryKindLabels,
              value: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: TextField(
              controller: _amount,
              autofocus: !editing,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: _kind == EntryKind.income
                    ? IosColors.green
                    : Ios.label(context),
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                filled: false,
                suffixText: 'ر.س',
                suffixStyle: TextStyle(
                  fontSize: 20,
                  color: Ios.secondary(context),
                ),
              ),
            ),
          ),
          if (_kind == EntryKind.income)
            IosSection(
              header: 'من أين؟',
              footer: sources.isEmpty ? 'أضف مصدر الإيراد أولاً.' : null,
              dividerIndent: 60,
              children: [
                if (sources.isNotEmpty)
                  IosTile(
                    leading: const IconBadge(
                      CupertinoIcons.building_2_fill,
                      IosColors.teal,
                    ),
                    title: 'مصدر الإيراد',
                    value: source?.name ?? 'اختر',
                    chevron: true,
                    onTap: () async {
                      final v = await pickFromList<IncomeSource>(
                        context,
                        items: sources,
                        initial: source ?? sources.first,
                        label: (s) => '${s.name} (${s.type})',
                      );
                      if (v != null) setState(() => _sourceId = v.id);
                    },
                  ),
                IosTile(
                  leading: const IconBadge(CupertinoIcons.add, IosColors.blue),
                  title: 'مصدر جديد...',
                  titleColor: Ios.tint(context),
                  onTap: () async {
                    final id = await editSource(
                      context,
                      ref,
                      widget.estateId,
                      null,
                    );
                    if (id != null) setState(() => _sourceId = id);
                  },
                ),
              ],
            ),
          if (_kind == EntryKind.expense)
            IosSection(
              children: [
                IosTile(
                  title: 'بند المصروف',
                  value: _category,
                  chevron: true,
                  onTap: () async {
                    final v = await pickFromList<String>(
                      context,
                      items: cats,
                      initial: _category,
                      label: (c) => c,
                    );
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ],
            ),
          if (_kind == EntryKind.distribution)
            IosSection(
              footer: heir == null
                  ? null
                  : 'المتبقي لهذا الوارث: ${Fmt.money(heir.remaining)}',
              children: [
                IosTile(
                  title: 'الوارث',
                  value: heir?.heir.name ?? 'اختر',
                  chevron: true,
                  onTap: heirs.isEmpty
                      ? null
                      : () async {
                          final v = await pickFromList(
                            context,
                            items: heirs,
                            initial: heir ?? heirs.first,
                            label: (h) => h.heir.name,
                          );
                          if (v != null) setState(() => _heirId = v.heir.id);
                        },
                ),
              ],
            ),
          IosSection(
            children: [
              IosTile(
                title: 'التاريخ',
                value: Fmt.date(_date),
                chevron: true,
                onTap: () async {
                  final v = await pickDateTime(context, _date, withTime: false);
                  if (v != null) setState(() => _date = v);
                },
              ),
              IosField(_note, 'البيان / ملاحظة', maxLines: 3),
            ],
          ),
          if (editing)
            IosSection(
              children: [
                IosTile(
                  title: 'حذف الحركة',
                  titleColor: IosColors.red,
                  onTap: () async {
                    if (await confirmDialog(context, 'حذف هذه الحركة؟')) {
                      await estateRepo.deleteEntry(widget.entry!.id!);
                      refreshEstate(ref, widget.estateId);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
