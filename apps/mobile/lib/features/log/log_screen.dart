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
import '../../widgets/nyla_ui.dart';

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
    final values = {
      for (final value in valuesAsync.value ?? const <DayValueEntry>[]) value.key: value,
    };
    final customLogs = (ref.watch(customLogsProvider).value ?? const <CustomLogEntry>[])
        .where((entry) => !entry.archived)
        .toList(growable: false);
    _loadNoteOnce();

    return NylaPage(
      title: 'Check in',
      subtitle: friendlyDay(day),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayRail(
            day: day,
            onPrevious: () => _changeDay(day.addDays(-1)),
            onNext: () => _changeDay(day.addDays(1)),
          ),
          const SizedBox(height: 16),
          _FlowPanel(
            selected: values['flow']?.value,
            onChanged: (value) async {
              await NylaHaptics.select();
              await _setChoice(flowDefinition, value);
            },
            onMarkPeriod: _markPeriod,
          ),
          const SizedBox(height: 26),
          NylaSectionHeader(
            eyebrow: 'BODY & MIND',
            title: 'What feels worth noting?',
            trailing: values.isEmpty
                ? null
                : Text(
                    '${values.length} logged',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NylaColors.wine,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: builtInLogs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.42,
            ),
            itemBuilder: (context, index) {
              final definition = builtInLogs[index];
              return _LogInstrument(
                definition: definition,
                summary: _summary(definition, values),
                index: index,
                onTap: () => _edit(definition, values),
              );
            },
          ),
          const SizedBox(height: 26),
          NylaSectionHeader(
            eyebrow: 'YOUR SPACE',
            title: customLogs.isEmpty ? 'Track something personal' : 'Your own logs',
            actionLabel: customLogs.isEmpty ? 'Add' : 'Manage',
            onAction: () {
              NylaHaptics.select();
              context.push('/settings/logs');
            },
          ),
          if (customLogs.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customLogs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.42,
              ),
              itemBuilder: (context, index) {
                final custom = customLogs[index];
                final definition = LogDefinition(
                  key: custom.key,
                  label: custom.label,
                  icon: Icons.bookmark_rounded,
                  tint: index.isEven ? NylaColors.lavender : NylaColors.sage,
                );
                return _LogInstrument(
                  definition: definition,
                  summary: _summary(definition, values),
                  index: index + builtInLogs.length,
                  onTap: () => _edit(definition, values),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 12),
            _AddPersonalLog(
              onTap: () {
                NylaHaptics.select();
                context.push('/settings/logs');
              },
            ),
          ],
          const SizedBox(height: 34),
          _NotesPage(
            controller: _noteController,
            onSave: () async {
              await NylaHaptics.confirm();
              await ref.read(dayLogRepositoryProvider).setNote(
                    epochDay: day.epochDay,
                    note: _noteController.text,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note saved')),
                );
              }
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Nothing is required. A quiet day can stay quiet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 92),
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
      ref.read(dayLogRepositoryProvider).setValue(
            epochDay: day.epochDay,
            key: definition.key,
            value: value,
          );

  Future<void> _markPeriod() async {
    await NylaHaptics.confirm();
    await ref.read(cycleRepositoryProvider).recordPeriod(start: day);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Period start recorded')),
      );
    }
  }

  Future<void> _edit(LogDefinition definition, Map<String, DayValueEntry> values) async {
    await NylaHaptics.select();
    if (definition.kind == LogKind.choice) {
      final chosen = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => _ChoiceSheet(
          definition: definition,
          selected: values[definition.key]?.value,
        ),
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

  Future<void> _applyMultiChoice(LogDefinition definition, Set<String> before, Set<String> after) async {
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

class _DayRail extends StatelessWidget {
  const _DayRail({required this.day, required this.onPrevious, required this.onNext});
  final LocalDay day;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final today = LocalDay.fromDateTime(DateTime.now());
    final isToday = day == today;
    return NylaPaperSurface(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      radius: const BorderRadius.all(Radius.circular(22)),
      child: Row(
        children: [
          _DayButton(icon: Icons.arrow_back_rounded, onTap: onPrevious),
          Expanded(
            child: Column(
              children: [
                Text(isToday ? 'Today' : friendlyDay(day), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(isToday ? 'A moment for yourself' : 'Past check-in', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          _DayButton(icon: Icons.arrow_forward_rounded, onTap: day.epochDay < today.epochDay ? onNext : null),
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        enabled: onTap != null,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: onTap == null ? NylaColors.canvas : NylaColors.roseWash, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: onTap == null ? NylaColors.faintInk : NylaColors.wine),
        ),
      );
}

class _FlowPanel extends StatelessWidget {
  const _FlowPanel({required this.selected, required this.onChanged, required this.onMarkPeriod});
  final String? selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onMarkPeriod;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
        decoration: BoxDecoration(
          color: NylaColors.roseWash,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NylaColors.roseSoft.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const NylaIconToken(icon: Icons.water_drop_rounded, background: NylaColors.wine, foreground: Colors.white),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bleeding', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text('Choose the closest match.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8 * 4) / 5;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < flowDefinition.choices.length; i++) ...[
                      SizedBox(
                        width: width,
                        child: _FlowChoice(
                          choice: flowDefinition.choices[i],
                          index: i,
                          selected: selected == flowDefinition.choices[i].id,
                          onTap: () => onChanged(flowDefinition.choices[i].id),
                        ),
                      ),
                      if (i != flowDefinition.choices.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
            if (selected != null && selected != 'none' && selected != 'spotting') ...[
              const SizedBox(height: 16),
              NylaPressable(
                onTap: onMarkPeriod,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 18, color: NylaColors.wine),
                    const SizedBox(width: 7),
                    Text('Mark this as period start', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: NylaColors.wine)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}

class _FlowChoice extends StatelessWidget {
  const _FlowChoice({required this.choice, required this.index, required this.selected, required this.onTap});
  final LogChoice choice;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18 + (index * 3.6),
              height: 18 + (index * 3.6),
              decoration: BoxDecoration(
                color: selected ? NylaColors.wine : Colors.white.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(color: selected ? NylaColors.wine : NylaColors.rose.withValues(alpha: 0.22), width: 1.3),
                boxShadow: selected ? const [BoxShadow(color: Color(0x25381426), blurRadius: 12, offset: Offset(0, 4))] : null,
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
            ),
            const SizedBox(height: 8),
            Text(
              choice.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? NylaColors.wine : NylaColors.mutedInk,
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _LogInstrument extends StatelessWidget {
  const _LogInstrument({required this.definition, required this.summary, required this.index, required this.onTap});
  final LogDefinition definition;
  final String? summary;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = summary != null;
    const radius = BorderRadius.all(Radius.circular(18));
    return NylaPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(15, 15, 14, 14),
        decoration: BoxDecoration(
          color: active ? definition.tint.withValues(alpha: 0.42) : NylaColors.paper,
          borderRadius: radius,
          border: Border.all(
            color: active ? NylaColors.violet.withValues(alpha: 0.18) : NylaColors.outline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NylaIconToken(
                  icon: definition.icon,
                  background: active ? Colors.white.withValues(alpha: 0.76) : definition.tint.withValues(alpha: 0.44),
                  foreground: NylaColors.wine,
                  size: 38,
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: active ? NylaColors.wine : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: active ? NylaColors.wine : NylaColors.outlineStrong),
                  ),
                  child: active ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                ),
              ],
            ),
            const Spacer(),
            Text(definition.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              summary ?? 'Tap to add',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: active ? NylaColors.wine : NylaColors.faintInk,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPersonalLog extends StatelessWidget {
  const _AddPersonalLog({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
          decoration: BoxDecoration(border: Border.all(color: NylaColors.outlineStrong), borderRadius: BorderRadius.circular(22)),
          child: Row(
            children: [
              const NylaIconToken(icon: Icons.add_rounded, background: NylaColors.sageSoft, foreground: NylaColors.wine),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create a personal log', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Name it once, then it lives with your daily check-in.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: NylaColors.faintInk),
            ],
          ),
        ),
      );
}

class _NotesPage extends StatelessWidget {
  const _NotesPage({required this.controller, required this.onSave});
  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => NylaPaperSurface(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
        radius: BorderRadius.circular(20),
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NylaOverline('PRIVATE NOTE'),
            const SizedBox(height: 6),
            Text('Anything else?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              'Add a detail only when you want to remember it later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 7,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Write a note…', counterText: ''),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Save note'),
              ),
            ),
          ],
        ),
      );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 3, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NylaOverline('TODAY'),
              const SizedBox(height: 7),
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 27)),
              const SizedBox(height: 5),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.selected, required this.onTap, this.subtitle});
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? NylaColors.roseWash : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? NylaColors.roseSoft : NylaColors.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.5)),
                    ],
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? NylaColors.wine : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? NylaColors.wine : NylaColors.outlineStrong),
                ),
                child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 13) : null,
              ),
            ],
          ),
        ),
      );
}

class _SeveritySheet extends StatelessWidget {
  const _SeveritySheet({required this.definition, required this.selected});
  final LogDefinition definition;
  final int? selected;

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: definition.label,
        subtitle: 'Choose the closest fit. You can change it later.',
        child: Column(
          children: [
            for (var index = 0; index < severityChoices.length; index++) ...[
              _ChoiceRow(
                label: severityChoices[index].label,
                subtitle: index == 0 ? 'Records an explicit “none” rather than leaving the day unknown.' : null,
                selected: selected == index,
                onTap: () {
                  NylaHaptics.select();
                  Navigator.pop(context, index);
                },
              ),
              if (index != severityChoices.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      );
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.definition, required this.selected});
  final LogDefinition definition;
  final String? selected;

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: definition.label,
        subtitle: 'Choose what feels most accurate today.',
        child: Column(
          children: [
            for (var index = 0; index < definition.choices.length; index++) ...[
              _ChoiceRow(
                label: definition.choices[index].label,
                selected: selected == definition.choices[index].id,
                onTap: () {
                  NylaHaptics.select();
                  Navigator.pop(context, definition.choices[index].id);
                },
              ),
              if (index != definition.choices.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      );
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
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 3, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NylaOverline('TODAY'),
              const SizedBox(height: 7),
              Text(widget.definition.label, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 27)),
              const SizedBox(height: 5),
              Text('Choose as many as fit.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              Wrap(
                spacing: 9,
                runSpacing: 9,
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
