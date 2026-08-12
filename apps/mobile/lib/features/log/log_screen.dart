import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/model/date_text.dart';
import '../../core/model/log_catalog.dart';
import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';
import '../../widgets/nyla_page.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({this.initialDay, super.key});

  final LocalDay? initialDay;

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  late LocalDay day = widget.initialDay ?? LocalDay.fromDateTime(DateTime.now());
  final _noteController = TextEditingController();
  bool _noteLoaded = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valuesAsync = ref.watch(dayValuesProvider(day.epochDay));
    final values = {for (final value in valuesAsync.value ?? const <DayValueEntry>[]) value.key: value};
    final customLogs = (ref.watch(customLogsProvider).value ?? const <CustomLogEntry>[])
        .where((entry) => !entry.archived)
        .toList(growable: false);
    _loadNoteOnce();

    return NylaPage(
      title: 'Log',
      subtitle: friendlyDay(day),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayPicker(
            day: day,
            onPrevious: () => _changeDay(day.addDays(-1)),
            onNext: () => _changeDay(day.addDays(1)),
          ),
          const SizedBox(height: 14),
          _FlowCard(
            selected: values['flow']?.value,
            onChanged: (value) => _setChoice(flowDefinition, value),
            onMarkPeriod: _markPeriod,
          ),
          const SizedBox(height: 14),
          Text('How did your body feel?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: builtInLogs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.05,
            ),
            itemBuilder: (context, index) {
              final definition = builtInLogs[index];
              return _LogTile(
                definition: definition,
                summary: _summary(definition, values),
                onTap: () => _edit(definition, values),
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (customLogs.isNotEmpty)
                Expanded(child: Text('Your logs', style: Theme.of(context).textTheme.titleLarge))
              else
                const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/settings/logs'),
                icon: Icon(customLogs.isEmpty ? Icons.add_rounded : Icons.tune_rounded, size: 18),
                label: Text(customLogs.isEmpty ? 'Add your own log' : 'Manage'),
              ),
            ],
          ),
          if (customLogs.isNotEmpty) ...[
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customLogs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.05,
              ),
              itemBuilder: (context, index) {
                final custom = customLogs[index];
                final definition = LogDefinition(
                  key: custom.key,
                  label: custom.label,
                  icon: Icons.favorite_outline_rounded,
                  tint: NylaColors.lavender,
                );
                return _LogTile(
                  definition: definition,
                  summary: _summary(definition, values),
                  onTap: () => _edit(definition, values),
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          Text('A note, if you want', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 9),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 7,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Anything worth remembering…',
              counterText: '',
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              await ref.read(dayLogRepositoryProvider).setNote(epochDay: day.epochDay, note: _noteController.text);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
            },
            child: const Text('Save note'),
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing here is required. Log only what is useful to you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String? _summary(LogDefinition definition, Map<String, DayValueEntry> values) {
    if (definition.kind == LogKind.multiChoice) {
      final selected = definition.choices
          .where((choice) => values.containsKey('${definition.key}.${choice.id}'))
          .map((choice) => choice.label)
          .toList(growable: false);
      if (selected.isEmpty) return null;
      if (selected.length <= 2) return selected.join(', ');
      return '${selected.take(2).join(', ')} +${selected.length - 2}';
    }
    final current = values[definition.key];
    if (current == null) return null;
    if (definition.kind == LogKind.choice) return definition.choiceLabel(current.value);
    final severity = current.severity;
    if (severity == null || severity < 0 || severity >= severityChoices.length) return current.value;
    return severityChoices[severity].label;
  }

  void _changeDay(LocalDay next) {
    final today = LocalDay.fromDateTime(DateTime.now());
    if (next.epochDay > today.epochDay) return;
    setState(() {
      day = next;
      _noteLoaded = false;
      _noteController.clear();
    });
  }

  Future<void> _loadNoteOnce() async {
    if (_noteLoaded) return;
    _noteLoaded = true;
    final note = await ref.read(dayLogRepositoryProvider).noteForDay(day.epochDay);
    if (mounted && _noteController.text.isEmpty) _noteController.text = note ?? '';
  }

  Future<void> _setChoice(LogDefinition definition, String value) =>
      ref.read(dayLogRepositoryProvider).setValue(epochDay: day.epochDay, key: definition.key, value: value);

  Future<void> _markPeriod() async {
    await ref.read(cycleRepositoryProvider).recordPeriod(start: day);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Period start recorded')));
  }

  Future<void> _edit(LogDefinition definition, Map<String, DayValueEntry> values) async {
    if (definition.kind == LogKind.choice) {
      final current = values[definition.key]?.value;
      final chosen = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => _ChoiceSheet(definition: definition, selected: current),
      );
      if (chosen != null) await _setChoice(definition, chosen);
      return;
    }

    if (definition.kind == LogKind.multiChoice) {
      final selected = <String>{
        for (final choice in definition.choices)
          if (values.containsKey('${definition.key}.${choice.id}')) choice.id,
      };
      final chosen = await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _MultiChoiceSheet(definition: definition, initial: selected),
      );
      if (chosen == null) return;
      await _applyMultiChoice(definition, selected, chosen);
      return;
    }

    final current = values[definition.key];
    final severity = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SeveritySheet(definition: definition, selected: current?.severity),
    );
    if (severity == null) return;
    await ref.read(dayLogRepositoryProvider).setValue(
          epochDay: day.epochDay,
          key: definition.key,
          value: severityChoices[severity].id,
          severity: severity,
        );
  }

  Future<void> _applyMultiChoice(
    LogDefinition definition,
    Set<String> before,
    Set<String> after,
  ) async {
    final repository = ref.read(dayLogRepositoryProvider);
    for (final choice in definition.choices) {
      final key = '${definition.key}.${choice.id}';
      if (after.contains(choice.id) && !before.contains(choice.id)) {
        await repository.setValue(epochDay: day.epochDay, key: key, value: choice.id);
      } else if (!after.contains(choice.id) && before.contains(choice.id)) {
        await repository.clearValue(epochDay: day.epochDay, key: key);
      }
    }
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.day, required this.onPrevious, required this.onNext});

  final LocalDay day;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final today = LocalDay.fromDateTime(DateTime.now());
    return Row(
      children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text(
            day == today ? 'Today' : friendlyDay(day),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          onPressed: day.epochDay < today.epochDay ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.selected, required this.onChanged, required this.onMarkPeriod});

  final String? selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onMarkPeriod;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: NylaColors.roseSoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.water_drop_rounded, color: NylaColors.rose),
                ),
                const SizedBox(width: 11),
                Text('Bleeding', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final choice in flowDefinition.choices)
                  ChoiceChip(
                    label: Text(choice.label),
                    selected: selected == choice.id,
                    onSelected: (_) => onChanged(choice.id),
                  ),
              ],
            ),
            if (selected != null && selected != 'none' && selected != 'spotting') ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onMarkPeriod,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Mark this as a period start'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.definition, required this.summary, required this.onTap});

  final LogDefinition definition;
  final String? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: definition.tint, borderRadius: BorderRadius.circular(13)),
                child: Icon(definition.icon, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(definition.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (summary != null)
                      Text(
                        summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeveritySheet extends StatelessWidget {
  const _SeveritySheet({required this.definition, required this.selected});

  final LogDefinition definition;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(definition.label, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Choose what fits. You can change it anytime.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            for (var index = 0; index < severityChoices.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(severityChoices[index].label),
                subtitle: index == 0 ? const Text('Records an explicit “none” rather than leaving the day unknown') : null,
                trailing: selected == index ? const Icon(Icons.check_circle_rounded, color: NylaColors.rose) : null,
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.definition, required this.selected});

  final LogDefinition definition;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(definition.label, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            for (final choice in definition.choices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(choice.label),
                trailing: selected == choice.id ? const Icon(Icons.check_circle_rounded, color: NylaColors.rose) : null,
                onTap: () => Navigator.pop(context, choice.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _MultiChoiceSheet extends StatefulWidget {
  const _MultiChoiceSheet({required this.definition, required this.initial});

  final LogDefinition definition;
  final Set<String> initial;

  @override
  State<_MultiChoiceSheet> createState() => _MultiChoiceSheetState();
}

class _MultiChoiceSheetState extends State<_MultiChoiceSheet> {
  late final Set<String> selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.definition.label, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Choose as many as fit.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in widget.definition.choices)
                  FilterChip(
                    label: Text(choice.label),
                    selected: selected.contains(choice.id),
                    onSelected: (enabled) {
                      setState(() {
                        if (enabled) {
                          selected.add(choice.id);
                        } else {
                          selected.remove(choice.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.pop(context, Set<String>.unmodifiable(selected)),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
