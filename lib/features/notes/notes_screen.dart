import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../tasks/tasks_screen.dart' show showSearchDialog;
import 'note_editor.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملاحظات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final q = await showSearchDialog(context, _q);
              if (q != null) setState(() => _q = q);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditor()),
        ),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (notes) {
          final list = _q.isEmpty
              ? notes
              : notes
                    .where(
                      (n) => n.title.contains(_q) || n.content.contains(_q),
                    )
                    .toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.sticky_note_2_outlined,
              message: 'لا توجد ملاحظات',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => _NoteCard(note: list[i]),
          );
        },
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final color = Color(note.color);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteEditor(note: note)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.30 : 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? 'بدون عنوان' : note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (note.pinned) Icon(Icons.push_pin, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                note.content,
                overflow: TextOverflow.fade,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(
              Fmt.shortDate(note.updatedAt),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
