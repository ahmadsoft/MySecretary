import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../calendar/event_form.dart' show ColorPicker;

class NoteEditor extends ConsumerStatefulWidget {
  final Note? note;
  const NoteEditor({super.key, this.note});

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _content = TextEditingController(text: widget.note?.content);
  late int _color = widget.note?.color ?? IosColors.yellow.toARGB32();
  late bool _pinned = widget.note?.pinned ?? false;
  bool _saved = false;

  /// الحفظ التلقائي عند الخروج.
  Future<void> _save() async {
    if (_saved) return;
    _saved = true;
    final t = _title.text.trim(), c = _content.text.trim();
    if (t.isEmpty && c.isEmpty) return;
    await noteRepo.save(
      Note(
        id: widget.note?.id,
        title: t,
        content: c,
        color: _color,
        pinned: _pinned,
      ),
    );
    ref.invalidate(notesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: Ios.cell(context),
        appBar: AppBar(
          backgroundColor: Ios.cell(context),
          actions: [
            NavIcon(
              _pinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
              tooltip: 'تثبيت',
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            IconButton(
              tooltip: 'اللون',
              icon: Icon(
                CupertinoIcons.circle_fill,
                color: Color(_color),
                size: 24,
              ),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: ColorPicker(
                    selected: _color,
                    onChanged: (v) {
                      setState(() => _color = v);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            ),
            if (widget.note != null)
              NavIcon(
                CupertinoIcons.trash,
                tooltip: 'حذف',
                onPressed: () async {
                  if (await confirmDialog(context, 'حذف الملاحظة؟')) {
                    _saved = true;
                    await noteRepo.delete(widget.note!.id!);
                    ref.invalidate(notesProvider);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            NavTextButton('تم', onPressed: () => Navigator.maybePop(context)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                Fmt.dateTime(widget.note?.updatedAt ?? DateTime.now()),
                style: TextStyle(fontSize: 13, color: Ios.secondary(context)),
              ),
              TextField(
                controller: _title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: 'العنوان',
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _content,
                  autofocus: widget.note == null,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 17, height: 1.5),
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'اكتب ملاحظتك...',
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
