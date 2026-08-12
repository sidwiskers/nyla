import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              final current = values[definition.key];
              return _LogTile(
                definition: definition,
                current: current,
                onTap: () => _edit(definition, current),
              );
            },
          ),
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

  Future<void> _edit(LogDefinition definition, DayValueEntry? current) async {
    if (definition.kind == LogKind.choice) {
      final chosen = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => _ChoiceSheet(definition: definition, selected: current?.value),
      );
      if (chosen != null) await _setChoice(definition, chosen);
      return;
    }

    final severity = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SeveritySheet(definition: definition, selected: current?.severity),
    );
    if (severity == null) return;
    if (severity == 0) {
      await ref.read(dayLogRepositoryProvider).clearValue(epochDay: day.epochDay, key: definition.key);
    } else {
      await ref.read(dayLogRepositoryProvider).setValue(
            epochDay: day.epochDay,
            key: definition.key,
            value: severityLabels[severity],
            severity: severity,
          );
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
                for (final value in flowDefinition.choices)
                  ChoiceChip(
                    label: Text(value),
                    selected: selected == value,
                    onSelected: (_) => onChanged(value),
                  ),
              ],
            ),
            if (selected != null && selected != 'None' && selected != 'Spotting') ...[
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
  const _LogTile({required this.definition, required this.current, required this.onTap});

  final LogDefinition definition;
  final DayValueEntry? current;
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
                    if (current != null)
                      Text(
                        current!.value,
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
            for (var index = 0; index < severityLabels.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(severityLabels[index]),
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
                title: Text(choice),
                trailing: selected == choice ? const Icon(Icons.check_circle_rounded, color: NylaColors.rose) : null,
                onTap: () => Navigator.pop(context, choice),
              ),
          ],
        ),
      ),
    );
  }
}
