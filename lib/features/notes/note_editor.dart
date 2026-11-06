import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late int _color = widget.note?.color ?? 0xFF1E6F5C;
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
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'تثبيت',
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            IconButton(
              tooltip: 'اللون',
              icon: Icon(Icons.palette, color: Color(_color)),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
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
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirmDialog(context, 'حذف الملاحظة؟')) {
                    _saved = true;
                    await noteRepo.delete(widget.note!.id!);
                    ref.invalidate(notesProvider);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                controller: _title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'العنوان',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _content,
                  autofocus: widget.note == null,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'اكتب ملاحظتك...',
                    border: InputBorder.none,
                    filled: false,
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
