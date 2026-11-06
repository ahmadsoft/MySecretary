import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'note_editor.dart';

/// الملاحظات بطابع تطبيق الملاحظات في iPhone.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملاحظات'),
        actions: [
          NavIcon(
            CupertinoIcons.square_pencil,
            tooltip: 'ملاحظة جديدة',
            onPressed: () =>
                Navigator.push(context, iosRoute(const NoteEditor())),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (notes) {
          final list = _q.isEmpty
              ? notes
              : notes
                    .where(
                      (n) => n.title.contains(_q) || n.content.contains(_q),
                    )
                    .toList();
          final pinned = list.where((n) => n.pinned).toList();
          final others = list.where((n) => !n.pinned).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: CupertinoSearchTextField(
                  controller: _search,
                  placeholder: 'بحث',
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
              if (list.isEmpty)
                const SizedBox(
                  height: 300,
                  child: EmptyState(
                    icon: CupertinoIcons.doc_text,
                    message: 'لا توجد ملاحظات',
                  ),
                ),
              if (pinned.isNotEmpty)
                IosSection(
                  header: 'مثبّتة',
                  children: [for (final n in pinned) _NoteRow(note: n)],
                ),
              if (others.isNotEmpty)
                IosSection(
                  header: pinned.isEmpty ? null : 'الملاحظات',
                  children: [for (final n in others) _NoteRow(note: n)],
                ),
              if (list.isNotEmpty)
                Center(
                  child: Text(
                    '${list.length} ملاحظات',
                    style: TextStyle(
                      fontSize: 13,
                      color: Ios.secondary(context),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final Note note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final preview = note.content.replaceAll('\n', ' ');
    return InkWell(
      onTap: () => Navigator.push(context, iosRoute(NoteEditor(note: note))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: Color(note.color),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'بدون عنوان' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Ios.label(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${Fmt.shortDate(note.updatedAt)}  ',
                          style: TextStyle(color: Ios.label(context)),
                        ),
                        TextSpan(
                          text: preview.isEmpty ? 'لا يوجد نص إضافي' : preview,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: Ios.secondary(context),
                    ),
                  ),
                ],
              ),
            ),
            if (note.pinned)
              Icon(CupertinoIcons.pin_fill, size: 14, color: IosColors.orange),
          ],
        ),
      ),
    );
  }
}
