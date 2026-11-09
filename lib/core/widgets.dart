import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';

// ═══════════════════════ عناصر واجهة بطابع iOS ═══════════════════════

/// شريط علوي بعنوان كبير للشاشات الرئيسية (Large Title).
PreferredSizeWidget largeTitleBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    centerTitle: false,
    toolbarHeight: 60,
    titleSpacing: 20,
    title: Text(
      title,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: Ios.label(context),
        letterSpacing: -0.4,
      ),
    ),
    actions: [...?actions, const SizedBox(width: 8)],
    bottom: bottom,
  );
}

/// زر أيقونة في شريط التنقل بطابع iOS.
class NavIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  const NavIcon(this.icon, {super.key, this.onPressed, this.tooltip});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 25, color: Ios.tint(context)),
  );
}

/// زر نصي في شريط التنقل (مثل: حفظ، تم).
class NavTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool bold;
  const NavTextButton(this.text, {super.key, this.onPressed, this.bold = true});

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    onPressed: onPressed,
    child: Text(
      text,
      style: TextStyle(
        color: Ios.tint(context),
        fontSize: 17,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

/// قسم مجمّع بزوايا دائرية (Inset Grouped) مثل إعدادات iPhone.
class IosSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final double dividerIndent;
  final Widget? headerTrailing;
  final EdgeInsetsGeometry margin;

  const IosSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.dividerIndent = 16,
    this.headerTrailing,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 22),
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(indent: dividerIndent, height: 0.5));
      }
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null || headerTrailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      header ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Ios.secondary(context),
                      ),
                    ),
                  ),
                  ?headerTrailing,
                ],
              ),
            ),
          GlassPanel(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(fontSize: 13, color: Ios.secondary(context)),
              ),
            ),
        ],
      ),
    );
  }
}

/// عنوان قسم بخط عريض (مثل أقسام تطبيق التذكيرات).
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 8, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Ios.label(context),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// أيقونة داخل مربع ملون بزوايا دائرية (مثل أيقونات الإعدادات في iPhone).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(this.icon, this.color, {super.key, this.size = 30});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.24),
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.6),
  );
}

/// صف داخل قسم مجمّع.
class IosTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final String? value; // نص رمادي على الطرف
  final VoidCallback? onTap;
  final bool chevron;
  final Color? titleColor;
  final bool bold;

  const IosTile({
    super.key,
    this.leading,
    this.title = '',
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron = false,
    this.titleColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final sub =
        subtitleWidget ??
        (subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Ios.secondary(context)),
              ));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 14, 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget ??
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            color: titleColor ?? Ios.label(context),
                            fontWeight: bold
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    if (sub != null) ...[const SizedBox(height: 2), sub],
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Text(
                    value!,
                    style: TextStyle(
                      fontSize: 17,
                      color: Ios.secondary(context),
                    ),
                  ),
                ),
              if (trailing != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
                  ),
                ),
              if (chevron)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 18,
                    color: Ios.tertiary(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل نصي داخل قسم مجمّع (بدون حدود).
class IosField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int? maxLines;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextStyle? style;
  final String? suffix;
  final ValueChanged<String>? onSubmitted;

  const IosField(
    this.controller,
    this.placeholder, {
    super.key,
    this.maxLines = 1,
    this.autofocus = false,
    this.keyboardType,
    this.style,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    maxLines: maxLines,
    minLines: 1,
    keyboardType: keyboardType,
    onSubmitted: onSubmitted,
    style: style ?? const TextStyle(fontSize: 17),
    decoration: InputDecoration(
      hintText: placeholder,
      suffixText: suffix,
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

/// مفتاح التبديل بشكل iOS.
class IosSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const IosSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
    value: value,
    activeTrackColor: IosColors.green,
    onChanged: onChanged,
  );
}

/// أداة التحديد المقسّمة (Segmented Control) بشكل iOS.
class IosSegmented<T extends Object> extends StatelessWidget {
  final Map<T, String> items;
  final T value;
  final ValueChanged<T> onChanged;
  const IosSegmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : const Color(0x1F767680),
      thumbColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF636366)
          : Colors.white,
      children: {
        for (final e in items.entries)
          e.key: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: FittedBox(
              child: Text(
                e.value,
                style: TextStyle(fontSize: 14, color: Ios.label(context)),
              ),
            ),
          ),
      },
      onValueChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

/// دائرة الإنجاز (مثل تطبيق التذكيرات).
class IosCheck extends StatelessWidget {
  final bool done;
  final Color color;
  final VoidCallback onTap;
  const IosCheck({
    super.key,
    required this.done,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: done
            ? Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                key: const ValueKey(1),
                size: 26,
                color: color,
              )
            : Container(
                key: const ValueKey(0),
                width: 23,
                height: 23,
                margin: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.8),
                ),
              ),
      ),
    ),
  );
}

/// حالة فارغة موحدة.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Ios.tertiary(context)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Ios.secondary(context), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر شريط علوي لفلترة القوائم (حبوب).
class FilterPills<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  const FilterPills({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onSelected(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == selected ? Ios.tint(context) : Ios.cell(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label(v),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: v == selected ? Colors.white : Ios.label(context),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ═══════════════════════ نوافذ وحوارات iOS ═══════════════════════

/// نافذة تأكيد بشكل iOS.
Future<bool> confirmDialog(
  BuildContext context,
  String message, {
  String ok = 'حذف',
  bool destructive = true,
}) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('تأكيد'),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// رسالة بشكل iOS.
Future<void> infoDialog(BuildContext context, String title, String message) =>
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );

/// إدخال نص في نافذة بشكل iOS.
Future<String?> promptDialog(
  BuildContext context, {
  required String title,
  String? message,
  String placeholder = '',
  String initial = '',
  int maxLines = 1,
  String ok = 'تم',
}) {
  final c = TextEditingController(text: initial);
  return showCupertinoDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message),
            ),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: c,
            autofocus: true,
            placeholder: placeholder,
            maxLines: maxLines,
            minLines: 1,
            onSubmitted: maxLines == 1
                ? (v) => Navigator.pop(ctx, v.trim())
                : null,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: Text(ok),
        ),
      ],
    ),
  );
}

class SheetAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool destructive;
  const SheetAction(
    this.label,
    this.onPressed, {
    this.icon,
    this.destructive = false,
  });
}

/// قائمة خيارات من الأسفل (Action Sheet) بشكل iOS.
Future<void> showActionSheet(
  BuildContext context,
  List<SheetAction> actions, {
  String? title,
}) => showCupertinoModalPopup<void>(
  context: context,
  builder: (ctx) => CupertinoActionSheet(
    title: title == null ? null : Text(title),
    actions: [
      for (final a in actions)
        CupertinoActionSheetAction(
          isDestructiveAction: a.destructive,
          onPressed: () {
            Navigator.pop(ctx);
            a.onPressed();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (a.icon != null) ...[
                Icon(a.icon, size: 22),
                const SizedBox(width: 8),
              ],
              Text(a.label),
            ],
          ),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(
      isDefaultAction: true,
      onPressed: () => Navigator.pop(ctx),
      child: const Text('إلغاء'),
    ),
  ),
);

/// اختيار عنصر من قائمة بعجلة iOS.
Future<T?> pickFromList<T>(
  BuildContext context, {
  required List<T> items,
  required T initial,
  required String Function(T) label,
}) async {
  var selected = items.contains(initial) ? initial : items.first;
  final ok = await _bottomPicker(
    context,
    CupertinoPicker(
      itemExtent: 38,
      scrollController: FixedExtentScrollController(
        initialItem: items.indexOf(selected),
      ),
      onSelectedItemChanged: (i) => selected = items[i],
      children: [for (final i in items) Center(child: Text(label(i)))],
    ),
  );
  return ok ? selected : null;
}

Future<bool> _bottomPicker(BuildContext context, Widget picker) async {
  final r = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => Container(
      height: 300,
      color: Ios.cell(ctx),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                CupertinoButton(
                  child: const Text('إلغاء'),
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const Spacer(),
                CupertinoButton(
                  child: const Text(
                    'تم',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
            const Divider(height: 0.5),
            Expanded(child: picker),
          ],
        ),
      ),
    ),
  );
  return r ?? false;
}

/// اختيار تاريخ (ووقت) بعجلة iOS.
Future<DateTime?> pickDateTime(
  BuildContext context,
  DateTime initial, {
  bool withTime = true,
}) async {
  var value = initial;
  final ok = await _bottomPicker(
    context,
    CupertinoDatePicker(
      initialDateTime: initial,
      minimumYear: 2000,
      maximumYear: 2100,
      mode: withTime
          ? CupertinoDatePickerMode.dateAndTime
          : CupertinoDatePickerMode.date,
      onDateTimeChanged: (d) => value = d,
    ),
  );
  if (!ok) return null;
  return withTime ? value : DateTime(value.year, value.month, value.day);
}

void toast(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg)));

/// صفحة بنمط iOS (للتنقل).
Route<T> iosRoute<T>(Widget page) =>
    CupertinoPageRoute<T>(builder: (_) => page);

/// نافذة منبثقة كاملة (Sheet) بنمط iOS مع زري إلغاء/حفظ.
Future<T?> showIosSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => child,
    );

/// رأس نافذة منبثقة: إلغاء — العنوان — حفظ
class SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSave;
  final String saveLabel;
  const SheetHeader({
    super.key,
    required this.title,
    this.onSave,
    this.saveLabel = 'حفظ',
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Ios.label(context),
            ),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: onSave,
          child: Text(
            saveLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
