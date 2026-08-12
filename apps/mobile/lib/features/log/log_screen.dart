import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics/nyla_haptics.dart';
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
            onChanged: (value) async {
              await NylaHaptics.select();
              await _setChoice(flowDefinition, value);
            },
            onMarkPeriod: _markPeriod,
          ),
          const SizedBox(height: 22),
          _SectionHeading(
            title: 'How did your body feel?',
            subtitle: values.isEmpty ? 'Pick only what matters today.' : '${values.length} things are already in today’s log.',
          ),
          const SizedBox(height: 11),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: builtInLogs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.72,
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
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (customLogs.isNotEmpty)
                const Expanded(
                  child: _SectionHeading(title: 'Your logs', subtitle: 'The things you chose to track.'),
                )
              else
                const Expanded(
                  child: _SectionHeading(title: 'Make it yours', subtitle: 'Add a log that Nyla does not include yet.'),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  NylaHaptics.select();
                  context.push('/settings/logs');
                },
                icon: Icon(customLogs.isEmpty ? Icons.add_rounded : Icons.tune_rounded, size: 18),
                label: Text(customLogs.isEmpty ? 'Add' : 'Manage'),
              ),
            ],
          ),
          if (customLogs.isNotEmpty) ...[
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customLogs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.72,
              ),
              itemBuilder: (context, index) {
                final custom = customLogs[index];
                final definition = LogDefinition(
                  key: custom.key,
                  label: custom.label,
                  icon: Icons.favorite_outline_rounded,
                  tint: index.isEven ? NylaColors.lavender : NylaColors.sage,
                );
                return _LogTile(
                  definition: definition,
                  summary: _summary(definition, values),
                  onTap: () => _edit(definition, values),
                );
              },
            ),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [NylaColors.peachSoft, NylaColors.lavenderSoft]),
              borderRadius: BorderRadius.circular(29),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('A note, if you want', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text('Private, searchable context for future you.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 13),
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
                const SizedBox(height: 11),
                FilledButton.icon(
                  onPressed: () async {
                    await NylaHaptics.confirm();
                    await ref.read(dayLogRepositoryProvider).setNote(epochDay: day.epochDay, note: _noteController.text);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save note'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nothing here is required. Log only what is useful to you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 82),
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
    NylaHaptics.select();
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
    await NylaHaptics.confirm();
    await ref.read(cycleRepositoryProvider).recordPeriod(start: day);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Period start recorded')));
  }

  Future<void> _edit(LogDefinition definition, Map<String, DayValueEntry> values) async {
    await NylaHaptics.select();
    if (definition.kind == LogKind.choice) {
      final current = values[definition.key]?.value;
      final chosen = await showModalBottomSheet<String>(
        context: context,
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
        builder: (context) => _MultiChoiceSheet(definition: definition, initial: selected),
      );
      if (chosen == null) return;
      await _applyMultiChoice(definition, selected, chosen);
      return;
    }

    final current = values[definition.key];
    final severity = await showModalBottomSheet<int>(
      context: context,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
        ],
      );
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.day, required this.onPrevious, required this.onNext});

  final LocalDay day;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final today = LocalDay.fromDateTime(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _DayButton(onPressed: onPrevious, icon: Icons.chevron_left_rounded),
          Expanded(
            child: Column(
              children: [
                Text(
                  day == today ? 'Today' : friendlyDay(day),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (day != today)
                  Text('Past log', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          _DayButton(
            onPressed: day.epochDay < today.epochDay ? onNext : null,
            icon: Icons.chevron_right_rounded,
          ),
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({required this.onPressed, required this.icon});

  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
        color: onPressed == null ? NylaColors.roseWash.withValues(alpha: 0.45) : NylaColors.roseWash,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: onPressed == null ? NylaColors.faintInk : NylaColors.wine,
        ),
      );
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.selected, required this.onChanged, required this.onMarkPeriod});

  final String? selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onMarkPeriod;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [NylaColors.roseSoft, NylaColors.peachSoft]),
        borderRadius: BorderRadius.circular(29),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: NylaColors.wine, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bleeding', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text('What best matches today?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            Material(
              color: Colors.white.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onMarkPeriod,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 18, color: NylaColors.wine),
                      SizedBox(width: 7),
                      Text('Mark as period start', style: TextStyle(color: NylaColors.wine, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
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
    final active = summary != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: definition.tint.withValues(alpha: active ? 0.9 : 0.58),
            borderRadius: BorderRadius.circular(24),
            border: active ? Border.all(color: NylaColors.wine.withValues(alpha: 0.16)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(definition.icon, size: 19, color: NylaColors.wine),
                  ),
                  const Spacer(),
                  if (active)
                    const Icon(Icons.check_circle_rounded, color: NylaColors.wine, size: 18)
                  else
                    const Icon(Icons.add_rounded, color: NylaColors.mutedInk, size: 18),
                ],
              ),
              const Spacer(),
              Text(
                definition.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: NylaColors.ink, fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              const SizedBox(height: 3),
              Text(
                summary ?? 'Not logged',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10.8,
                      color: active ? NylaColors.wine : NylaColors.mutedInk,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
                onTap: () {
                  NylaHaptics.select();
                  Navigator.pop(context, index);
                },
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
                onTap: () {
                  NylaHaptics.select();
                  Navigator.pop(context, choice.id);
                },
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
                      NylaHaptics.select();
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
              onPressed: () {
                NylaHaptics.confirm();
                Navigator.pop(context, Set<String>.unmodifiable(selected));
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
