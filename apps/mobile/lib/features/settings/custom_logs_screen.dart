import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';

class CustomLogsScreen extends ConsumerWidget {
  const CustomLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(customLogsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your custom logs'), backgroundColor: Colors.transparent),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        error: (_, _) => const Center(child: Text('Your custom logs could not be loaded.')),
        data: (items) {
          final active = items.where((item) => !item.archived).toList(growable: false);
          final archived = items.where((item) => item.archived).toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: NylaColors.lavender, borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.tune_rounded),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Text(
                          'Track something Nyla does not include by default. Custom logs use the same simple intensity scale. Archiving hides a log without erasing its history.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('Shown while logging', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(child: Column(children: _tiles(context, ref, active))),
              ],
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('Archived', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(child: Column(children: _tiles(context, ref, archived))),
              ],
              if (items.isEmpty) ...[
                const SizedBox(height: 44),
                const Icon(Icons.add_reaction_outlined, size: 38, color: NylaColors.mutedInk),
                const SizedBox(height: 12),
                Text('Nothing custom yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'The built-in logs remain available. Add your own only when it is useful to you.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add custom log'),
      ),
    );
  }

  List<Widget> _tiles(BuildContext context, WidgetRef ref, List<CustomLogEntry> logs) {
    final widgets = <Widget>[];
    for (var index = 0; index < logs.length; index++) {
      final item = logs[index];
      widgets.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: NylaColors.lavender, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.favorite_outline_rounded, size: 20),
          ),
          title: Text(item.label),
          subtitle: Text(item.archived ? 'Hidden · history kept' : 'Five-level intensity log'),
          onTap: () => _rename(context, ref, item),
          trailing: IconButton(
            tooltip: item.archived ? 'Show again' : 'Archive',
            onPressed: () => _archive(context, ref, item),
            icon: Icon(item.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
          ),
        ),
      );
      if (index != logs.length - 1) widgets.add(const Divider(height: 1, indent: 18, endIndent: 18));
    }
    return widgets;
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final label = await _labelDialog(context, title: 'Add custom log', action: 'Add');
    if (label == null) return;
    try {
      await ref.read(customLogRepositoryProvider).create(label);
    } on ArgumentError catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, CustomLogEntry item) async {
    final label = await _labelDialog(context, title: 'Rename custom log', action: 'Save', initial: item.label);
    if (label == null) return;
    try {
      await ref.read(customLogRepositoryProvider).rename(item.key, label);
    } on ArgumentError catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, CustomLogEntry item) async {
    try {
      await ref.read(customLogRepositoryProvider).setArchived(item.key, !item.archived);
    } on StateError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That custom log changed elsewhere.')));
      }
    }
  }

  Future<String?> _labelDialog(
    BuildContext context, {
    required String title,
    required String action,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'For example, leg aches'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(action)),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
