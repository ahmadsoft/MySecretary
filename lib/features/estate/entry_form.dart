import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل حركة' : 'حركة جديدة'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDialog(context, 'حذف هذه الحركة؟')) {
                  await estateRepo.deleteEntry(widget.entry!.id!);
                  refreshEstate(ref, widget.estateId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<EntryKind>(
            segments: [
              for (final k in EntryKind.values)
                ButtonSegment(value: k, label: Text(entryKindLabels[k]!)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: !editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'المبلغ',
              suffixText: 'ر.س',
            ),
          ),
          const SizedBox(height: 16),
          if (_kind == EntryKind.income) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: sources.any((s) => s.id == _sourceId)
                        ? _sourceId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'مصدر الإيراد (من أين؟)',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    items: [
                      for (final s in sources)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name} (${s.type})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _sourceId = v),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'مصدر جديد',
                  icon: const Icon(Icons.add),
                  onPressed: () async {
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
            if (sources.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'أضف مصدراً أولاً بالضغط على +',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
          if (_kind == EntryKind.expense)
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'بند المصروف',
                prefixIcon: Icon(Icons.category),
              ),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
          if (_kind == EntryKind.distribution)
            DropdownButtonFormField<int>(
              initialValue: heirs.any((h) => h.heir.id == _heirId)
                  ? _heirId
                  : null,
              decoration: const InputDecoration(
                labelText: 'الوارث',
                prefixIcon: Icon(Icons.person),
              ),
              items: [
                for (final h in heirs)
                  DropdownMenuItem(
                    value: h.heir.id,
                    child: Text(
                      '${h.heir.name} — المتبقي ${Fmt.money(h.remaining)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _heirId = v),
            ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('التاريخ'),
              subtitle: Text(Fmt.date(_date)),
              onTap: () async {
                final v = await pickDateTime(context, _date, withTime: false);
                if (v != null) setState(() => _date = v);
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'البيان / ملاحظة',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('حفظ'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}
