import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
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
    final editing = widget.tx?.id != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تفاصيل العملية' : 'عملية جديدة'),
        actions: [NavTextButton(editing ? 'تم' : 'إضافة', onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: IosSegmented<TxKind>(
              items: const {TxKind.expense: 'مصروف', TxKind.income: 'إيراد'},
              value: _kind,
              onChanged: (k) => setState(() {
                _kind = k;
                _categoryId = null;
              }),
            ),
          ),
          // المبلغ بخط كبير
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
                color: _kind == TxKind.income
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
          IosSection(
            header: 'التصنيف',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  runSpacing: 12,
                  children: [
                    for (final cat in cats)
                      SizedBox(
                        width: 82,
                        child: GestureDetector(
                          onTap: () => setState(() => _categoryId = cat.id),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _categoryId == cat.id
                                        ? Color(cat.color)
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: IconBadge(
                                  iconAt(cat.icon),
                                  Color(cat.color),
                                  size: 44,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cat.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _categoryId == cat.id
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: Ios.label(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          IosSection(
            footer: 'سيتذكر التطبيق تصنيف هذه الجهة للعمليات القادمة.',
            children: [
              IosField(
                _merchant,
                _kind == TxKind.expense ? 'الجهة / المتجر' : 'المصدر',
              ),
              IosField(_note, 'ملاحظة'),
            ],
          ),
          IosSection(
            children: [
              IosTile(
                title: 'التاريخ',
                value: Fmt.dateTime(_date),
                chevron: true,
                onTap: () async {
                  final d = await pickDateTime(context, _date);
                  if (d != null) setState(() => _date = d);
                },
              ),
              IosTile(
                title: 'طريقة الدفع',
                value: paymentLabels[_method],
                chevron: true,
                onTap: () async {
                  final v = await pickFromList<PaymentMethod>(
                    context,
                    items: PaymentMethod.values,
                    initial: _method,
                    label: (m) => paymentLabels[m]!,
                  );
                  if (v != null) setState(() => _method = v);
                },
              ),
            ],
          ),
          if (widget.tx?.rawSms != null)
            IosSection(
              header: 'نص الرسالة الأصلية',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    widget.tx!.rawSms!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Ios.secondary(context),
                    ),
                  ),
                ),
              ],
            ),
          if (editing)
            IosSection(
              children: [
                IosTile(
                  title: 'حذف العملية',
                  titleColor: IosColors.red,
                  onTap: () async {
                    if (await confirmDialog(context, 'حذف هذه العملية؟')) {
                      await financeRepo.deleteTx(widget.tx!.id!);
                      refreshFinance(ref);
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
