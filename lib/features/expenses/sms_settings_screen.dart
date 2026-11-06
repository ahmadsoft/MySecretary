import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
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
    final v = await promptDialog(
      context,
      title: 'إضافة مرسل',
      message: 'اسم المرسل كما يظهر في الرسائل',
      placeholder: 'مثال: AlRajhiBank',
      ok: 'إضافة',
    );
    if (v == null || v.isEmpty) return;
    setState(() => _senders = [..._senders, v]);
    await s.setSenders(_senders);
  }

  Future<void> _testParser() async {
    final txt = await promptDialog(
      context,
      title: 'تجربة قراءة رسالة',
      placeholder: 'الصق نص الرسالة',
      maxLines: 6,
      ok: 'تحليل',
    );
    if (txt == null || !mounted) return;
    final r = SmsParser.parse(txt);
    infoDialog(
      context,
      'النتيجة',
      r == null
          ? 'لم يتم التعرف على عملية مالية في هذه الرسالة.'
          : 'النوع: ${r.kind.name == 'expense' ? 'مصروف' : 'إيراد'}\n'
                'المبلغ: ${r.amount}\n'
                'الجهة: ${r.merchant.isEmpty ? '—' : r.merchant}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رسائل البنوك')),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              children: [
                Center(
                  child: IconBadge(
                    CupertinoIcons.chat_bubble_text_fill,
                    IosColors.green,
                    size: 64,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 12, 32, 22),
                  child: Text(
                    SmsService.supported
                        ? 'يقرأ "سكرتيري" رسائل البنوك ويسجل المصروفات والإيرادات تلقائياً مع تصنيفها. '
                              'تبقى الرسائل على جهازك، ورسائل رموز التحقق تُتجاهل دائماً.'
                        : 'نظام iOS لا يسمح لأي تطبيق بقراءة الرسائل النصية. '
                              'انسخ رسالة البنك ثم استخدم "لصق رسالة بنك" لتحليلها وتسجيلها تلقائياً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Ios.secondary(context),
                    ),
                  ),
                ),
                if (SmsService.supported) ...[
                  IosSection(
                    dividerIndent: 60,
                    children: [
                      IosTile(
                        leading: const IconBadge(
                          CupertinoIcons.envelope_fill,
                          IosColors.blue,
                        ),
                        title: 'القراءة التلقائية',
                        trailing: IosSwitch(
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
                      ),
                      IosTile(
                        leading: const IconBadge(
                          CupertinoIcons.bell_fill,
                          IosColors.red,
                        ),
                        title: 'إشعار عند التسجيل',
                        trailing: IosSwitch(
                          value: _notify,
                          onChanged: (v) async {
                            await s.setNotify(v);
                            setState(() => _notify = v);
                          },
                        ),
                      ),
                      IosTile(
                        leading: const IconBadge(
                          CupertinoIcons.arrow_2_circlepath,
                          IosColors.green,
                        ),
                        title: 'قراءة الرسائل الآن',
                        subtitle: 'أول مرة: تُستورد رسائل آخر 30 يوماً',
                        onTap: !_enabled
                            ? null
                            : () async {
                                final n = await s.syncInbox();
                                refreshFinance(ref);
                                if (context.mounted) {
                                  toast(context, 'تم تسجيل $n عملية جديدة');
                                }
                              },
                      ),
                    ],
                  ),
                  IosSection(
                    header: 'المرسلون المعتمدون',
                    footer: _senders.isEmpty
                        ? 'حالياً تُحلل رسائل جميع المرسلين. أضف أسماء البنوك لتقتصر القراءة عليها (مستحسن).'
                        : 'تُقرأ الرسائل من هؤلاء المرسلين فقط.',
                    children: [
                      for (final x in _senders)
                        IosTile(
                          title: x,
                          trailing: GestureDetector(
                            onTap: () async {
                              setState(
                                () => _senders = [..._senders]..remove(x),
                              );
                              await s.setSenders(_senders);
                            },
                            child: const Icon(
                              CupertinoIcons.minus_circle_fill,
                              color: IosColors.red,
                            ),
                          ),
                        ),
                      IosTile(
                        title: 'إضافة مرسل...',
                        titleColor: Ios.tint(context),
                        onTap: _addSender,
                      ),
                    ],
                  ),
                ],
                IosSection(
                  children: [
                    IosTile(
                      title: 'لصق رسالة بنك وتسجيلها',
                      titleColor: Ios.tint(context),
                      onTap: () => showPasteSmsDialog(context, ref),
                    ),
                    IosTile(
                      title: 'تجربة قراءة رسالة (بدون تسجيل)',
                      titleColor: Ios.tint(context),
                      onTap: _testParser,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
