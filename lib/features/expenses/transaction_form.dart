import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class TransactionForm extends ConsumerStatefulWidget {
  final Tx? tx;
  const TransactionForm({super.key, this.tx});

  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  late TxKind _kind = widget.tx?.kind ?? TxKind.expense;
  late final _amount = TextEditingController(
    text: widget.tx == null ? '' : widget.tx!.amount.toStringAsFixed(2),
  );
  late final _merchant = TextEditingController(text: widget.tx?.merchant);
  late final _note = TextEditingController(text: widget.tx?.note);
  late int? _categoryId = widget.tx?.categoryId;
  late DateTime _date = widget.tx?.date ?? DateTime.now();
  late PaymentMethod _method = widget.tx?.method ?? PaymentMethod.card;

  Future<void> _save() async {
    final amount = Fmt.parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      toast(context, 'أدخل مبلغاً صحيحاً');
      return;
    }
    final old = widget.tx;
    await financeRepo.saveTx(
      Tx(
        id: old?.id,
        kind: _kind,
        amount: amount,
        categoryId: _categoryId,
        merchant: _merchant.text.trim(),
        note: _note.text.trim(),
        date: _date,
        method: _method,
        fromSms: old?.fromSms ?? false,
        smsHash: old?.smsHash,
        rawSms: old?.rawSms,
      ),
    );
    refreshFinance(ref);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.kind == _kind)
        .toList();
    final c = Theme.of(context).colorScheme;
    final editing = widget.tx?.id != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل عملية' : 'عملية جديدة'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDialog(context, 'حذف هذه العملية؟')) {
                  await financeRepo.deleteTx(widget.tx!.id!);
                  refreshFinance(ref);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TxKind>(
            segments: const [
              ButtonSegment(
                value: TxKind.expense,
                label: Text('مصروف'),
                icon: Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: TxKind.income,
                label: Text('إيراد'),
                icon: Icon(Icons.arrow_downward),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              _categoryId = null;
            }),
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
          const Text('التصنيف', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in cats)
                ChoiceChip(
                  avatar: Icon(
                    iconAt(cat.icon),
                    size: 18,
                    color: Color(cat.color),
                  ),
                  label: Text(cat.name),
                  selected: _categoryId == cat.id,
                  onSelected: (_) => setState(() => _categoryId = cat.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _merchant,
            decoration: InputDecoration(
              labelText: _kind == TxKind.expense ? 'الجهة / المتجر' : 'المصدر',
              prefixIcon: const Icon(Icons.storefront),
              helperText: 'سيتذكر التطبيق تصنيف هذه الجهة للعمليات القادمة',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('التاريخ'),
                  subtitle: Text(Fmt.dateTime(_date)),
                  onTap: () async {
                    final d = await pickDateTime(context, _date);
                    if (d != null) setState(() => _date = d);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('طريقة الدفع'),
                  trailing: DropdownButton<PaymentMethod>(
                    value: _method,
                    underline: const SizedBox(),
                    items: [
                      for (final e in paymentLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _method = v!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'ملاحظة',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          if (widget.tx?.rawSms != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.sms, size: 18, color: c.outline),
                const SizedBox(width: 6),
                Text('نص الرسالة الأصلية', style: TextStyle(color: c.outline)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                widget.tx!.rawSms!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
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
