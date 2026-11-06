import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../services/sms_parser.dart';
import '../../services/sms_service.dart';
import 'expenses_screen.dart' show showPasteSmsDialog;

class SmsSettingsScreen extends ConsumerStatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  ConsumerState<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends ConsumerState<SmsSettingsScreen> {
  final s = SmsService.instance;
  bool _enabled = false, _notify = true, _loading = true;
  List<String> _senders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await s.isEnabled(),
        n = await s.notifyEnabled(),
        l = await s.senders();
    if (mounted) {
      setState(() {
        _enabled = e;
        _notify = n;
        _senders = l;
        _loading = false;
      });
    }
  }

  Future<void> _addSender() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مرسل'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اسم المرسل كما يظهر في الرسائل\nمثال: AlRajhiBank أو SNB-AlAhli',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    setState(() => _senders = [..._senders, v]);
    await s.setSenders(_senders);
  }

  Future<void> _testParser() async {
    final c = TextEditingController();
    final txt = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تجربة قراءة رسالة'),
        content: TextField(
          controller: c,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'الصق نص الرسالة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('تحليل'),
          ),
        ],
      ),
    );
    if (txt == null || !mounted) return;
    final r = SmsParser.parse(txt);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('النتيجة'),
        content: Text(
          r == null
              ? 'لم يتم التعرف على عملية مالية في هذه الرسالة.'
              : 'النوع: ${r.kind.name == 'expense' ? 'مصروف' : 'إيراد'}\n'
                    'المبلغ: ${r.amount}\n'
                    'الجهة: ${r.merchant.isEmpty ? '—' : r.merchant}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('رسائل البنوك')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Card(
                  color: c.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      SmsService.supported
                          ? 'عند التفعيل يقرأ "سكرتيري" رسائل البنوك الواردة ويسجل المصروفات والإيرادات تلقائياً مع تصنيفها. '
                                'تبقى الرسائل على جهازك ولا تُرسل لأي جهة. رسائل رموز التحقق تُتجاهل دائماً.'
                          : 'نظام iOS لا يسمح لأي تطبيق بقراءة الرسائل النصية. '
                                'بدلاً من ذلك: انسخ رسالة البنك ثم اضغط "لصق رسالة بنك" وسيتم تحليلها وتسجيلها تلقائياً.',
                      style: TextStyle(color: c.onSecondaryContainer),
                    ),
                  ),
                ),
                if (SmsService.supported) ...[
                  SwitchListTile(
                    title: const Text('القراءة التلقائية لرسائل البنوك'),
                    secondary: const Icon(Icons.sms),
                    value: _enabled,
                    onChanged: (v) async {
                      final ok = await s.setEnabled(v);
                      if (!ok && context.mounted) {
                        toast(
                          context,
                          'يجب السماح بإذن قراءة الرسائل من إعدادات الجهاز',
                        );
                      }
                      await _load();
                      refreshFinance(ref);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('إشعار عند تسجيل عملية'),
                    secondary: const Icon(Icons.notifications),
                    value: _notify,
                    onChanged: (v) async {
                      await s.setNotify(v);
                      setState(() => _notify = v);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('قراءة الرسائل الآن'),
                    subtitle: const Text(
                      'أول مرة: يتم استيراد رسائل آخر 30 يوماً',
                    ),
                    enabled: _enabled,
                    onTap: () async {
                      final n = await s.syncInbox();
                      refreshFinance(ref);
                      if (context.mounted) {
                        toast(context, 'تم تسجيل $n عملية جديدة');
                      }
                    },
                  ),
                  const SectionTitle('المرسلون المعتمدون'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _senders.isEmpty
                          ? 'حالياً: تُحلل رسائل جميع المرسلين. أضف أسماء البنوك لتقتصر القراءة عليها (مستحسن).'
                          : 'تُقرأ الرسائل من هؤلاء المرسلين فقط:',
                      style: TextStyle(color: c.outline),
                    ),
                  ),
                  for (final x in _senders)
                    ListTile(
                      leading: const Icon(Icons.account_balance),
                      title: Text(x),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          setState(() => _senders = [..._senders]..remove(x));
                          await s.setSenders(_senders);
                        },
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('إضافة مرسل (بنك)'),
                    onTap: _addSender,
                  ),
                  const Divider(),
                ],
                ListTile(
                  leading: const Icon(Icons.content_paste),
                  title: const Text('لصق رسالة بنك وتسجيلها'),
                  onTap: () => showPasteSmsDialog(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('تجربة قراءة رسالة (بدون تسجيل)'),
                  onTap: _testParser,
                ),
              ],
            ),
    );
  }
}
