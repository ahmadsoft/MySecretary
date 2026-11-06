import 'package:flutter/material.dart';

/// حالة فارغة موحدة.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: c.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.outline, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context,
  String message, {
  String ok = 'حذف',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تأكيد'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg)));

/// اختيار تاريخ ووقت معاً.
Future<DateTime?> pickDateTime(
  BuildContext context,
  DateTime initial, {
  bool withTime = true,
}) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (d == null) return null;
  if (!withTime || !context.mounted) return DateTime(d.year, d.month, d.day);
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (t == null) {
    return DateTime(d.year, d.month, d.day, initial.hour, initial.minute);
  }
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}
